CREATE OR REPLACE FUNCTION Finance.process_recurring_transactions(
    p_client_id INT,
    p_execution_date DATE
)
RETURNS TABLE(
    executed_count INT,
    failed_count INT,
    message TEXT
) AS $$
DECLARE
    v_template_id INT;
    v_transaction_id INT;
    v_failed_count INT := 0;
    v_executed_count INT := 0;
    v_error_msg TEXT;
    
    v_cursor CURSOR FOR
        SELECT template_id 
        FROM Finance.recurring_templates
        WHERE client_id = p_client_id 
        AND is_active = TRUE;
BEGIN
    OPEN v_cursor;
    
    LOOP
        FETCH v_cursor INTO v_template_id;
        EXIT WHEN NOT FOUND;
        
        BEGIN
            -- Insert transaction for this recurring template
            INSERT INTO Finance.transactions 
                (description, client_id, created_at)
            SELECT 
                template_name,
                p_client_id,
                NOW()
            FROM Finance.recurring_templates
            WHERE template_id = v_template_id
            RETURNING transaction_id INTO v_transaction_id;
            
            -- Insert journal entries from recurring_details
            INSERT INTO Finance.journals 
                (transaction_id, chart_id, date, journal, amount)
            SELECT 
                v_transaction_id,
                chart_id,
                p_execution_date,
                is_debit,
                amount
            FROM Finance.recurring_details
            WHERE template_id = v_template_id;
            
            -- Mark as executed
            UPDATE Finance.recurring_executions
            SET status = 'EXECUTED', 
                executed_date = NOW(),
                transaction_id = v_transaction_id
            WHERE template_id = v_template_id
            AND scheduled_date = p_execution_date;
            
            v_executed_count := v_executed_count + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_failed_count := v_failed_count + 1;
            v_error_msg := SQLERRM;
            
            UPDATE Finance.recurring_executions
            SET status = 'FAILED',
                error_message = v_error_msg
            WHERE template_id = v_template_id
            AND scheduled_date = p_execution_date;
        END;
    END LOOP;
    
    CLOSE v_cursor;
    
    RETURN QUERY SELECT v_executed_count, v_failed_count, 'Recurring transactions processed'::TEXT;
END;
$$ LANGUAGE plpgsql;