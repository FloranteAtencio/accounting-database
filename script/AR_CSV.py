import psycopg2
import json
import csv

# 1. SETUP CONNECTION
stg_table = 'Staging.stg_ar_imports'
conn = psycopg2.connect(
    host="localhost",
    database="erp_db", 
    user="erp_admin", 
    password="p2r0o2d6uction!", 
    port=5432
)
cur = conn.cursor()

# 2. START SESSION
print("🚀 Starting Import Session...")
try:
    cur.execute(
        "SELECT Finance.start_import_session(%s, %s, %s, %s)", 
        (101, 'invoices', 'admin_user', 'data.csv')
    )
    session_id = cur.fetchone()[0]
    print(f"✅ Session ID: {session_id}")

except Exception as e:
    print(f"❌ Failed to start session: {e}")
    conn.close()
    exit(1)

# 3. PROCESS CSV
try:
    with open('data.csv', 'r', newline='', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        
        for i, row in enumerate(reader, start=1):
            staging_id = None  # Initialize before try block
            try:
                # --- INSERT INTO STAGING ---
                query = f"""
                    INSERT INTO {stg_table} ( 
                        session_id, 
                        client_code,
                        customer_code, 
                        invoice_date, 
                        due_date, 
                        amount, 
                        validation_status, 
                        validation_errors, 
                        imported_at) 
                    VALUES (%s, %s, %s, %s, %s, 'PENDING', NULL, NOW())
                    RETURNING ar_staging_id
                    """
                values = (
                    session_id,
                    row['client_code'],
                    row['customer_code'],
                    row['invoice_date'],
                    row['due_date'],
                    row['amount'] 
                )

                cur.execute(query, values)
                staging_id = cur.fetchone()[0] 
                
                # Log workflow
                query = """ 
                    INSERT INTO Staging.import_workflows
                        (session_id, staging_record_id, staging_table, 
                         previous_state, new_state, change_by)
                    VALUES(%s, %s, %s, 'DRAFT', NULL, current_user)
                """
                values = (session_id, staging_id, stg_table)
                cur.execute(query, values)
                
                # Log success
                cur.execute(
                    "SELECT Finance.log_import_record(%s, %s, %s, %s, %s, %s, %s)",
                    (session_id, i, stg_table, json.dumps(row), 'SUCCESS', None, staging_id)
                )

            except Exception as e:
                error_msg = str(e)
                cur.execute(
                    "SELECT Finance.log_import_record(%s, %s, %s, %s, %s, %s, %s)",
                    (session_id, i, stg_table, json.dumps(row), 'FAILED', error_msg, staging_id)
                )
                print(f"⚠️ Row {i} failed: {error_msg}")

    # 4. VALIDATE (SQL) - FIXED
    print("🔍 Validating data...")
    
    # Validate table name (prevent SQL injection)
    if not stg_table.replace('.', '').replace('_', '').isalnum():
        raise ValueError("Invalid table name")
    
    validation_query = f"""
        UPDATE {stg_table} s
        SET 
            validation_status = CASE 
                WHEN b.customer_id IS NULL THEN 'INVALID'
                WHEN c.client_id IS NULL THEN 'INVALID'
                WHEN s.amount !~ '^[0-9.]+$' THEN 'INVALID'
                WHEN s.invoice_date !~ '^\d{{4}}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$' THEN 'INVALID'  
                WHEN s.due_date !~ '^\d{{4}}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$' THEN 'INVALID'  
                ELSE 'VALID'
            END,
            validation_error = CASE 
                WHEN b.customer_id IS NULL THEN 'Customer not found'
                WHEN c.client_id IS NULL THEN 'Client not found'
                WHEN s.amount !~ '^[0-9.]+$' THEN 'Invalid amount format'
                WHEN s.invoice_date !~ '^\d{{4}}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$' THEN 'Invalid Date'  
                WHEN s.due_date !~ '^\d{{4}}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$' THEN 'Invalid Date'
                ELSE NULL
            END
        FROM Finance.clients c
        JOIN Finance.customer b ON b.customer_id = s.customer_code 
        WHERE s.client_code = c.client_id
        AND s.session_id = %s
        AND s.validation_status = 'PENDING'
    """
    cur.execute(validation_query, (session_id,))

    # Update workflow status - FIXED
    update_workflow_query = f"""
        UPDATE Staging.import_workflows a
        SET
            new_state = 'VALIDATED',
            previous_state = 'DRAFT'
        FROM {stg_table} b
        WHERE a.staging_record_id = b.id 
        AND a.session_id = b.session_id
        AND b.validation_status = 'VALID'
    """
    print("Changing Status...")  
    cur.execute(update_workflow_query)

    # 5. COMPLETE SESSION
    print("✅ Import Loop Finished. Finalizing...")
    final_status = 'SUCCESS' 
    
    cur.execute(
        "SELECT Finance.complete_import_session(%s, %s, %s)",
        (session_id, final_status, 'Import completed successfully.')
    )
    
    conn.commit()
    print(f"🎉 Import Complete! Session {session_id} marked as {final_status}.")

except Exception as e:
    print(f"💥 CRITICAL ERROR: {e}")
    try:
        cur.execute(
            "SELECT Finance.complete_import_session(%s, %s, %s)",
            (session_id, 'FAILED', f'Script crashed: {str(e)}')
        )
        conn.rollback()
        conn.commit()
        print("⚠️ Session marked as FAILED due to crash.")
    except:
        pass

finally:
    cur.close()
    conn.close()