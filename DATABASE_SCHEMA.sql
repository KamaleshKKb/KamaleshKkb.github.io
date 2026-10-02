-- ============================================================================
-- PHARMACY POS + INVENTORY MANAGEMENT SAAS
-- COMPLETE DATABASE SCHEMA
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- ============================================================================
-- CORE TABLES
-- ============================================================================

-- Organizations (Tenants)
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) NOT NULL UNIQUE,
  email VARCHAR(100),
  phone VARCHAR(20),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100),
  postal_code VARCHAR(20),
  subscription_status VARCHAR(50) NOT NULL DEFAULT 'active',
  subscription_plan_id UUID,
  max_branches INT DEFAULT 1,
  max_users INT DEFAULT 5,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_org_slug (slug),
  INDEX idx_org_status (subscription_status)
);

-- Branches
CREATE TABLE branches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL,
  address TEXT,
  phone VARCHAR(20),
  email VARCHAR(100),
  manager_id UUID,
  latitude DECIMAL(10, 8),
  longitude DECIMAL(11, 8),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, code),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_branch_org (organization_id),
  INDEX idx_branch_active (is_active)
);

-- Users
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100),
  phone VARCHAR(20),
  profile_image_url VARCHAR(255),
  is_active BOOLEAN DEFAULT true,
  email_verified BOOLEAN DEFAULT false,
  email_verified_at TIMESTAMP,
  last_login_at TIMESTAMP,
  failed_login_attempts INT DEFAULT 0,
  locked_until TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_user_email (email),
  INDEX idx_user_active (is_active)
);

-- Organization Users (User membership)
CREATE TABLE organization_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_owner BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  invited_at TIMESTAMP,
  joined_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, user_id),
  INDEX idx_org_user_org (organization_id),
  INDEX idx_org_user_user (user_id)
);

-- ============================================================================
-- RBAC TABLES
-- ============================================================================

-- Roles
CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  description TEXT,
  is_system_role BOOLEAN DEFAULT false,
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, name),
  INDEX idx_role_org (organization_id),
  INDEX idx_role_system (is_system_role)
);

-- Permissions
CREATE TABLE permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(100) NOT NULL UNIQUE,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  category VARCHAR(50),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_perm_code (code),
  INDEX idx_perm_category (category)
);

-- Role Permissions
CREATE TABLE role_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(role_id, permission_id),
  INDEX idx_role_perm_role (role_id),
  INDEX idx_role_perm_perm (permission_id)
);

-- User Roles
CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES users(id),
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, user_id, role_id),
  INDEX idx_user_role_org (organization_id),
  INDEX idx_user_role_user (user_id),
  INDEX idx_user_role_role (role_id)
);

-- User Branch Access
CREATE TABLE user_branch_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES users(id),
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(user_id, branch_id),
  INDEX idx_branch_access_user (user_id),
  INDEX idx_branch_access_branch (branch_id),
  INDEX idx_branch_access_org (organization_id)
);

-- ============================================================================
-- MASTER DATA TABLES
-- ============================================================================

-- Categories
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, name),
  INDEX idx_cat_org (organization_id)
);

-- Manufacturers
CREATE TABLE manufacturers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  country VARCHAR(100),
  contact_email VARCHAR(100),
  contact_phone VARCHAR(20),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, name),
  INDEX idx_mfg_org (organization_id)
);

-- Medicines
CREATE TABLE medicines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  generic_name VARCHAR(255),
  brand_name VARCHAR(255),
  category_id UUID NOT NULL REFERENCES categories(id),
  manufacturer_id UUID NOT NULL REFERENCES manufacturers(id),
  strength VARCHAR(100),
  dosage_form VARCHAR(100),
  pack_size INT,
  unit VARCHAR(50),
  sku VARCHAR(100) NOT NULL,
  barcode VARCHAR(100),
  requires_prescription BOOLEAN DEFAULT false,
  tax_rate DECIMAL(5, 2) DEFAULT 0,
  reorder_level INT DEFAULT 10,
  reorder_quantity INT DEFAULT 50,
  status VARCHAR(50) DEFAULT 'active',
  notes TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, sku),
  UNIQUE(organization_id, barcode) WHERE barcode IS NOT NULL,
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_med_org (organization_id),
  INDEX idx_med_barcode (organization_id, barcode),
  INDEX idx_med_sku (organization_id, sku),
  INDEX idx_med_status (status)
);

-- Suppliers
CREATE TABLE suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  contact_person VARCHAR(150),
  email VARCHAR(100),
  phone VARCHAR(20),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100),
  postal_code VARCHAR(20),
  tax_id VARCHAR(50),
  payment_terms VARCHAR(100),
  opening_balance DECIMAL(15, 2) DEFAULT 0,
  current_balance DECIMAL(15, 2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_supp_org (organization_id),
  INDEX idx_supp_active (is_active)
);

-- Customers
CREATE TABLE customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(100),
  address TEXT,
  city VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100),
  postal_code VARCHAR(20),
  opening_balance DECIMAL(15, 2) DEFAULT 0,
  current_balance DECIMAL(15, 2) DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_cust_org (organization_id),
  INDEX idx_cust_branch (branch_id),
  INDEX idx_cust_active (is_active)
);

-- ============================================================================
-- BATCH & INVENTORY TABLES
-- ============================================================================

-- Batches
CREATE TABLE batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  medicine_id UUID NOT NULL REFERENCES medicines(id) ON DELETE CASCADE,
  batch_number VARCHAR(100) NOT NULL,
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  manufacturing_date DATE NOT NULL,
  expiry_date DATE NOT NULL,
  purchase_price DECIMAL(12, 2) NOT NULL,
  selling_price DECIMAL(12, 2) NOT NULL,
  original_quantity INT NOT NULL,
  remaining_quantity INT NOT NULL,
  purchase_reference VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, batch_number),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_batch_org (organization_id),
  INDEX idx_batch_medicine (medicine_id),
  INDEX idx_batch_expiry (expiry_date),
  INDEX idx_batch_remaining (remaining_quantity),
  CHECK (original_quantity > 0),
  CHECK (remaining_quantity >= 0),
  CHECK (remaining_quantity <= original_quantity),
  CHECK (expiry_date > manufacturing_date)
);

-- Inventory
CREATE TABLE inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  quantity_on_hand INT NOT NULL DEFAULT 0,
  quantity_reserved INT NOT NULL DEFAULT 0,
  quantity_available INT GENERATED ALWAYS AS (quantity_on_hand - quantity_reserved) STORED,
  last_counted_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, branch_id, batch_id),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_inv_org (organization_id),
  INDEX idx_inv_branch (branch_id),
  INDEX idx_inv_batch (batch_id),
  INDEX idx_inv_available (quantity_available),
  CHECK (quantity_on_hand >= 0),
  CHECK (quantity_reserved >= 0)
);

-- Inventory Movements
CREATE TABLE inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  batch_id UUID NOT NULL REFERENCES batches(id) ON DELETE CASCADE,
  movement_type VARCHAR(50) NOT NULL,
  quantity_change INT NOT NULL,
  quantity_before INT NOT NULL,
  quantity_after INT NOT NULL,
  reference_type VARCHAR(50),
  reference_id UUID,
  notes TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_mov_org (organization_id),
  INDEX idx_mov_branch (branch_id),
  INDEX idx_mov_batch (batch_id),
  INDEX idx_mov_type (movement_type),
  INDEX idx_mov_reference (reference_type, reference_id),
  INDEX idx_mov_created (created_at DESC),
  CHECK (movement_type IN (
    'opening_stock', 'purchase', 'sale', 'sale_return',
    'purchase_return', 'transfer_in', 'transfer_out',
    'adjustment', 'damage', 'expiry'
  ))
);

-- ============================================================================
-- PURCHASE TABLES
-- ============================================================================

-- Purchases
CREATE TABLE purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  supplier_id UUID NOT NULL REFERENCES suppliers(id),
  purchase_number VARCHAR(100) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'draft',
  total_quantity INT NOT NULL DEFAULT 0,
  total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  discount_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  net_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  paid_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  due_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  cancelled_at TIMESTAMP,
  
  UNIQUE(organization_id, purchase_number),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_purch_org (organization_id),
  INDEX idx_purch_branch (branch_id),
  INDEX idx_purch_supplier (supplier_id),
  INDEX idx_purch_status (status),
  INDEX idx_purch_created (created_at DESC),
  CHECK (status IN ('draft', 'completed', 'cancelled')),
  CHECK (net_amount >= 0),
  CHECK (paid_amount >= 0),
  CHECK (paid_amount <= net_amount)
);

-- Purchase Items
CREATE TABLE purchase_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  medicine_id UUID NOT NULL REFERENCES medicines(id),
  batch_number VARCHAR(100) NOT NULL,
  manufacturing_date DATE NOT NULL,
  expiry_date DATE NOT NULL,
  quantity INT NOT NULL,
  purchase_price DECIMAL(12, 2) NOT NULL,
  selling_price DECIMAL(12, 2) NOT NULL,
  tax_rate DECIMAL(5, 2) DEFAULT 0,
  discount_amount DECIMAL(12, 2) DEFAULT 0,
  line_total DECIMAL(15, 2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_purch_item_purchase (purchase_id),
  INDEX idx_purch_item_medicine (medicine_id),
  CHECK (quantity > 0),
  CHECK (purchase_price > 0),
  CHECK (selling_price > 0),
  CHECK (line_total > 0)
);

-- Purchase Payments
CREATE TABLE purchase_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  payment_date DATE NOT NULL,
  amount DECIMAL(15, 2) NOT NULL,
  payment_method VARCHAR(50) NOT NULL,
  reference_number VARCHAR(100),
  notes TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_purch_pay_purchase (purchase_id),
  INDEX idx_purch_pay_date (payment_date),
  CHECK (amount > 0),
  CHECK (payment_method IN ('cash', 'check', 'bank_transfer', 'credit'))
);

-- Purchase Returns
CREATE TABLE purchase_returns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  purchase_id UUID NOT NULL REFERENCES purchases(id),
  return_number VARCHAR(100) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'draft',
  total_quantity INT NOT NULL DEFAULT 0,
  total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  reason TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  
  UNIQUE(organization_id, return_number),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_purch_ret_purchase (purchase_id),
  INDEX idx_purch_ret_status (status),
  CHECK (status IN ('draft', 'completed', 'cancelled'))
);

-- Purchase Return Items
CREATE TABLE purchase_return_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  purchase_return_id UUID NOT NULL REFERENCES purchase_returns(id) ON DELETE CASCADE,
  batch_id UUID NOT NULL REFERENCES batches(id),
  quantity INT NOT NULL,
  unit_price DECIMAL(12, 2) NOT NULL,
  line_total DECIMAL(15, 2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_purch_ret_item_return (purchase_return_id),
  CHECK (quantity > 0)
);

-- ============================================================================
-- SALES TABLES
-- ============================================================================

-- Sales
CREATE TABLE sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id),
  invoice_number VARCHAR(100) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'draft',
  total_quantity INT NOT NULL DEFAULT 0,
  subtotal_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  tax_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  discount_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  cost_of_goods DECIMAL(15, 2) NOT NULL DEFAULT 0,
  profit DECIMAL(15, 2) GENERATED ALWAYS AS (total_amount - cost_of_goods) STORED,
  paid_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  due_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  payment_status VARCHAR(50) DEFAULT 'unpaid',
  notes TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  cancelled_at TIMESTAMP,
  
  UNIQUE(organization_id, invoice_number),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_sale_org (organization_id),
  INDEX idx_sale_branch (branch_id),
  INDEX idx_sale_customer (customer_id),
  INDEX idx_sale_status (status),
  INDEX idx_sale_created (created_at DESC),
  INDEX idx_sale_profit (profit),
  CHECK (status IN ('draft', 'completed', 'cancelled', 'returned')),
  CHECK (total_amount >= 0),
  CHECK (cost_of_goods >= 0),
  CHECK (paid_amount >= 0)
);

-- Sale Items
CREATE TABLE sale_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  batch_id UUID NOT NULL REFERENCES batches(id),
  quantity INT NOT NULL,
  unit_price DECIMAL(12, 2) NOT NULL,
  cost_price DECIMAL(12, 2) NOT NULL,
  tax_rate DECIMAL(5, 2) DEFAULT 0,
  discount_amount DECIMAL(12, 2) DEFAULT 0,
  line_total DECIMAL(15, 2) NOT NULL,
  line_cost DECIMAL(15, 2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_sale_item_sale (sale_id),
  INDEX idx_sale_item_batch (batch_id),
  CHECK (quantity > 0),
  CHECK (unit_price > 0),
  CHECK (cost_price >= 0)
);

-- Sale Payments
CREATE TABLE sale_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  payment_date TIMESTAMP NOT NULL,
  amount DECIMAL(15, 2) NOT NULL,
  payment_method VARCHAR(50) NOT NULL,
  reference_number VARCHAR(100),
  notes TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_sale_pay_sale (sale_id),
  INDEX idx_sale_pay_date (payment_date),
  CHECK (amount > 0),
  CHECK (payment_method IN ('cash', 'card', 'mobile_payment', 'credit', 'cheque'))
);

-- Sale Returns
CREATE TABLE sale_returns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  return_number VARCHAR(100) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'draft',
  total_quantity INT NOT NULL DEFAULT 0,
  total_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  cost_of_goods DECIMAL(15, 2) NOT NULL DEFAULT 0,
  refund_amount DECIMAL(15, 2) NOT NULL DEFAULT 0,
  reason TEXT,
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP,
  
  UNIQUE(organization_id, return_number),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_sale_ret_sale (sale_id),
  INDEX idx_sale_ret_status (status),
  CHECK (status IN ('draft', 'completed', 'rejected'))
);

-- Sale Return Items
CREATE TABLE sale_return_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  sale_return_id UUID NOT NULL REFERENCES sale_returns(id) ON DELETE CASCADE,
  sale_item_id UUID NOT NULL REFERENCES sale_items(id),
  quantity INT NOT NULL,
  unit_price DECIMAL(12, 2) NOT NULL,
  cost_price DECIMAL(12, 2) NOT NULL,
  line_total DECIMAL(15, 2) NOT NULL,
  line_cost DECIMAL(15, 2) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_sale_ret_item_return (sale_return_id),
  CHECK (quantity > 0)
);

-- ============================================================================
-- STOCK TRANSFER TABLES
-- ============================================================================

-- Stock Transfers
CREATE TABLE stock_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  from_branch_id UUID NOT NULL REFERENCES branches(id),
  to_branch_id UUID NOT NULL REFERENCES branches(id),
  transfer_number VARCHAR(100) NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'requested',
  total_quantity INT NOT NULL DEFAULT 0,
  requested_by UUID NOT NULL REFERENCES users(id),
  requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMP,
  dispatched_by UUID REFERENCES users(id),
  dispatched_at TIMESTAMP,
  received_by UUID REFERENCES users(id),
  received_at TIMESTAMP,
  cancelled_by UUID REFERENCES users(id),
  cancelled_at TIMESTAMP,
  notes TEXT,
  
  UNIQUE(organization_id, transfer_number),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_transfer_from (from_branch_id),
  INDEX idx_transfer_to (to_branch_id),
  INDEX idx_transfer_status (status),
  CHECK (from_branch_id != to_branch_id),
  CHECK (status IN ('requested', 'approved', 'dispatched', 'received', 'cancelled'))
);

-- Stock Transfer Items
CREATE TABLE stock_transfer_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  transfer_id UUID NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
  batch_id UUID NOT NULL REFERENCES batches(id),
  requested_quantity INT NOT NULL,
  dispatched_quantity INT,
  received_quantity INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_transfer_item_transfer (transfer_id),
  CHECK (requested_quantity > 0),
  CHECK (dispatched_quantity IS NULL OR dispatched_quantity > 0),
  CHECK (received_quantity IS NULL OR received_quantity > 0)
);

-- ============================================================================
-- EXPENSE TABLES
-- ============================================================================

-- Expense Categories
CREATE TABLE expense_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(100) NOT NULL,
  description TEXT,
  is_system_category BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, name),
  INDEX idx_exp_cat_org (organization_id)
);

-- Expenses
CREATE TABLE expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES expense_categories(id),
  amount DECIMAL(15, 2) NOT NULL,
  expense_date DATE NOT NULL,
  description TEXT,
  reference_number VARCHAR(100),
  payment_method VARCHAR(50),
  created_by UUID NOT NULL REFERENCES users(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_exp_org (organization_id),
  INDEX idx_exp_branch (branch_id),
  INDEX idx_exp_category (category_id),
  INDEX idx_exp_date (expense_date),
  CHECK (amount > 0)
);

-- ============================================================================
-- AUDIT & NOTIFICATIONS
-- ============================================================================

-- Audit Logs
CREATE TABLE audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  branch_id UUID REFERENCES branches(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id),
  action VARCHAR(100) NOT NULL,
  entity_type VARCHAR(100) NOT NULL,
  entity_id UUID,
  old_values JSONB,
  new_values JSONB,
  ip_address VARCHAR(45),
  user_agent TEXT,
  status VARCHAR(50) DEFAULT 'success',
  error_message TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_audit_org (organization_id),
  INDEX idx_audit_user (user_id),
  INDEX idx_audit_entity (entity_type, entity_id),
  INDEX idx_audit_action (action),
  INDEX idx_audit_created (created_at DESC)
);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(50) NOT NULL,
  reference_type VARCHAR(100),
  reference_id UUID,
  is_read BOOLEAN DEFAULT false,
  read_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_notif_user (user_id),
  INDEX idx_notif_org (organization_id{