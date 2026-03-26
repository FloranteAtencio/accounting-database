# 🧠 Bookkeeping Database System (PostgreSQL)

A modular **ERP-style database system** designed to handle inventory, sales, and financial transactions using PostgreSQL.

This project demonstrates real-world database engineering concepts including **data modeling, partitioning, transaction processing, and financial accounting logic**.

---

## 🚀 Features

* 📦 **Inventory Management**

  * Tracks stock movement across warehouses
  * Supports purchases, sales, transfers, and returns

* 💰 **Accounting System**

  * Double-entry bookkeeping (Debit/Credit)
  * Automatic journal entry generation

* 🧾 **Accounts Receivable / Payable**

  * Tracks customer balances and supplier obligations
  * Supports payment status and due dates

* ⚙️ **Stored Procedures (PL/pgSQL)**

  * Centralized transaction processing
  * Modular design (Inventory + Accounting modules)

* 🧩 **Partitioned Tables**

  * Scalable handling of financial data using date-based partitioning

* 📊 **Reporting & Dashboard Queries**

  * Inventory levels
  * Revenue and profit
  * Aging reports (AR/AP)

---

## 🏗️ System Architecture

```
[Transactions]
      ↓
[Inventory Module]
      ↓
[Accounting Module]
      ↓
[Journals / AR / AP]
```

---

## 🧠 Key Concepts Demonstrated

* Relational Database Design (Normalization, Constraints)
* Partitioning Strategy (Range Partitioning by Date)
* Composite Keys in Partitioned Tables
* Foreign Key Integrity across modules
* Financial Data Modeling (ERP-style logic)
* Query Optimization using Indexes
* Modular Stored Procedure Design

---

## 🛠️ Tech Stack

* **Database:** PostgreSQL
* **Language:** SQL / PLpgSQL
* **Tools:** pgAdmin / DBeaver (optional)

---

## ⚙️ How to Run

1. Clone the repository:

   ```bash
   git clone https://github.com/FloranteAtencio/ERP-Database.git
   ```

2. Open PostgreSQL (pgAdmin, DBeaver, or CLI)

3. Execute the SQL files in order:

   * Schema / Tables
   * Functions & Procedures
   * Sample Data (if available)

---

## 🧪 Sample Usage

### Create a Purchase Transaction

```sql
CALL devschema.process_inventory_transaction(
    1,              -- product_id
    1,              -- warehouse_id
    'Purchase',     -- action
    10,             -- quantity
    CURRENT_DATE,
    1               -- supplier_id
);
```

### Create a Sale Transaction

```sql
CALL devschema.process_inventory_transaction(
    1,
    1,
    'Sale',
    5,
    CURRENT_DATE,
    1               -- customer_id
);
```

---

## 📊 Example Queries

### Inventory Overview

```sql
SELECT product_id, warehouse_id,
SUM(CASE 
    WHEN action_type = 'Purchase' THEN quantity
    WHEN action_type = 'Sale' THEN -quantity
    ELSE 0 END) AS stock
FROM devschema.inventory_audit
GROUP BY product_id, warehouse_id;
```

---

### Accounting Balance Check

```sql
SELECT 
SUM(CASE WHEN is_debit THEN amount ELSE 0 END) AS total_debit,
SUM(CASE WHEN NOT is_debit THEN amount ELSE 0 END) AS total_credit
FROM devschema.journals;
```

---

## 💼 Business Value

This system simulates a real ERP backend where:

* Inventory transactions automatically affect financial records
* Sales generate accounts receivable
* Purchases generate accounts payable
* Financial reports can be derived from journal entries

---

## 📌 Future Improvements

* Automated partition creation (monthly)
* Materialized views for faster reporting
* Data warehouse integration (analytics layer)
* API or frontend dashboard integration

---

## 📄 License

This project is for educational and portfolio purposes.

---
