# Pharmacy POS + Inventory Management SaaS - Architecture Specification

## 1. EXECUTIVE ARCHITECTURE SUMMARY

This document specifies a production-ready, multi-tenant Pharmacy POS + Inventory Management SaaS architecture designed for small to medium pharmacy chains.

**Key Design Principles:**
- True multi-tenancy with complete data isolation
- Immutable audit trails for regulatory compliance
- Atomic transactions for all financial operations
- FEFO (First Expiry, First Out) built into core inventory logic
- Role-based access control (RBAC) with granular permissions
- Scalable from single-branch pharmacies to multi-branch chains
- Future-proof for payment gateways, notifications, and integrations

**Target Scale (Phase 1):**
- 100-1000 organizations
- 1-50 branches per organization
- 10-100 employees per branch
- 1,000-100,000 medicines per organization
- 100-10,000 transactions per day per branch

---

## 2. TECHNOLOGY STACK

### Frontend
**React 18 + TypeScript + Tailwind CSS + React Router 7**
- React: Industry standard, large ecosystem, excellent for complex UIs like POS
- TypeScript: Type safety for financial calculations and inventory logic
- Tailwind CSS: Rapid UI development with design consistency
- React Router 7: Client-side routing with loader functions for data pre-fetching
- State Management: React Context + custom hooks (start simple, migrate to Redux/Zustand if needed)
- Form Library: React Hook Form + Zod for validation
- UI Components: shadcn/ui for professional, accessible components
- Data Fetching: TanStack Query for caching and synchronization
- Charts: Recharts for reports and analytics

**Why:** React excels at complex UIs (POS interface, real-time inventory). TypeScript catches financial calculation errors at compile time. Tailwind enables rapid, consistent styling.

### Backend
**Node.js + Express + TypeScript**
- Node.js: JavaScript across full stack, excellent async I/O for database operations
- Express: Lightweight, mature, excellent middleware ecosystem
- TypeScript: Type safety for business logic and data transformations
- Validation: Zod for runtime schema validation
- ORM: Prisma for type-safe database access
- Authentication: JWT + bcrypt for secure password hashing
- Authorization: Custom middleware for RBAC enforcement

**Why:** Node.js provides excellent concurrency for multi-tenant SaaS. Prisma generates TypeScript types from schema, eliminating type mismatches. Express is battle-tested and lightweight.

### Database
**PostgreSQL 15+**
- ACID transactions for financial operations
- Row-level security (RLS) for tenant isolation
- JSON/JSONB for flexible data structures
- Full-text search for medicine lookup
- Window functions for inventory calculations
- Materialized views for reports
- Partitioning support for large tables (future)

**Why:** PostgreSQL's ACID guarantees are essential for pharmacy operations. RLS provides database-level tenant isolation. JSON support for audit trails. Window functions enable complex inventory queries.

### Deployment Stack
- **Backend:** Node.js on Docker/Kubernetes (or managed service like Railway, Render)
- **Database:** PostgreSQL managed service (AWS RDS, Supabase, Neon)
- **Frontend:** Static hosting (Vercel, Netlify)
- **Object Storage:** S3/MinIO for receipts, reports, backups
- **Message Queue:** Redis for job processing (future)
- **Email/SMS:** SendGrid/Twilio (future integrations)

---

## 3. SYSTEM ARCHITECTURE DIAGRAM

```
┌─────────────────────────────────────────────────────────────────┐
│                          CLIENT LAYER                            │
├──────────────────────┬──────────────────────┬───────────────────┤
│   React Web App      │   Mobile (Future)    │   Admin Dashboard  │
│   (POS, Reports)     │   (Customer App)     │   (Analytics)      │
└──────────────┬───────┴──────────────┬───────┴────────────┬───────┘
               │                      │                    │
               └──────────────────────┼────────────────────┘
                                      │ HTTPS/REST API
                ┌─────────────────────▼────────────────────┐
                │      API GATEWAY / LOAD BALANCER         │
                │  (Rate Limiting, CORS, Auth Validation)  │
                └──────────────────────┬────────────────────┘
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
        ▼                              ▼                              ▼
┌──────────────────┐        ┌──────────────────┐        ┌──────────────────┐
│  Auth Service    │        │  Core Service    │        │  Report Service  │
│  - Login         │        │  - POS           │        │  - Analytics     │
│  - JWT tokens    │        │  - Inventory     │        │  - Exports       │
│  - Refresh       │        │  - Purchases     │        │  - Dashboards    │
└────────┬─────────┘        └────────┬─────────┘        └────────┬─────────┘
         │                           │                           │
         └───────────────────────────┼───────────────────────────┘
                                     │
                    ┌────────────────▼────────────────┐
                    │   MIDDLEWARE LAYER              │
                    ├─────────────────────────────────┤
                    │ - Tenant Isolation              │
                    │ - RBAC Enforcement              │
                    │ - Audit Logging                 │
                    │ - Error Handling                │
                    │ - Request Validation            │
                    └────────────────┬────────────────┘
                                     │
                ┌────────────────────▼────────────────────┐
                │   DATABASE LAYER                       │
                ├────────────────────────────────────────┤
                │  PostgreSQL (Primary)                  │
                │  - Row-Level Security (RLS)            │
                │  - Audit Tables                        │
                │  - Inventory Views                     │
                │  - Financial Views                     │
                └────────────────────────────────────────┘
                                     │
        ┌────────────────────────────┼────────────────────────────┐
        │                            │                            │
        ▼                            ▼                            ▼
    ┌────────┐              ┌──────────────┐            ┌──────────────┐
    │ Backup │              │ Search Index │            │ Cache Layer  │
    │ (S3)   │              │ (Elasticsearch)           │ (Redis)      │
    └────────┘              └──────────────┘            └──────────────┘
```

---

## 4. MULTI-TENANT ARCHITECTURE

### Tenant Isolation Strategy: Database-Per-Schema

**Decision:** Shared database with schema-per-tenant + Row-Level Security

**Why not database-per-tenant:**
- Operational overhead
- Backup complexity
- Migration challenges
- Cost inefficiency at scale

**Why not row-level filtering:**
- Risk of data leakage if filtering logic fails
- Performance issues with large datasets
- Difficult to audit and verify isolation

**Recommended Approach: Hybrid**
- All tenants share one PostgreSQL database
- Each organization has a unique `organization_id`
- Row-Level Security (RLS) enforces tenant isolation at database level
- Backend middleware provides secondary isolation layer
- Query filtering ensures no cross-tenant data access

### Implementation Details

**1. Organization Table (Tenant Root)**
```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  slug VARCHAR(100) NOT NULL UNIQUE,
  subscription_status VARCHAR(50) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**2. Row-Level Security (RLS) Policy Example**
```sql
-- Enable RLS on all tables
ALTER TABLE medicines ENABLE ROW LEVEL SECURITY;

-- Policy: Users can only see medicines from their organization
CREATE POLICY org_isolation_policy ON medicines
  USING (organization_id = current_setting('app.current_organization_id')::UUID);

-- Set organization context before queries
SET app.current_organization_id = '550e8400-e29b-41d4-a716-446655440000';
```

**3. Backend Middleware (Secondary Layer)**
```typescript
// Middleware to enforce tenant isolation
async function tenantMiddleware(req, res, next) {
  const organizationId = req.user.organization_id;
  
  // Verify organization_id matches user's organization
  if (req.params.organizationId !== organizationId) {
    return res.status(403).json({ error: 'Unauthorized' });
  }
  
  // Set context for RLS
  await db.query(
    `SET app.current_organization_id = $1`,
    [organizationId]
  );
  
  next();
}
```

**4. Query Filtering (Tertiary Layer)**
```typescript
// Always filter by organization_id
const getMedicines = async (organizationId) => {
  return db.query(
    `SELECT * FROM medicines WHERE organization_id = $1`,
    [organizationId]
  );
};
```

**5. Indexing for Performance**
```sql
-- Critical indexes for multi-tenant queries
CREATE INDEX idx_medicines_org_id ON medicines(organization_id);
CREATE INDEX idx_medicines_org_id_barcode ON medicines(organization_id, barcode);
CREATE INDEX idx_batches_org_id ON batches(organization_id);
CREATE INDEX idx_sales_org_id_date ON sales(organization_id, created_at DESC);
CREATE INDEX idx_inventory_org_id ON inventory(organization_id);
```

**6. Unique Constraints Scoped to Organization**
```sql
-- Medicine SKU must be unique within organization (not globally)
ALTER TABLE medicines
ADD CONSTRAINT unique_sku_per_org UNIQUE (organization_id, sku);

-- Batch number must be unique within organization
ALTER TABLE batches
ADD CONSTRAINT unique_batch_number_per_org UNIQUE (organization_id, batch_number);
```

### Security Considerations

| Risk | Mitigation |
|------|-----------|
| RLS bypass | Always verify organization_id in application code; never trust client |
| Query injection | Use parameterized queries; validate inputs with Zod |
| Cross-org data leakage | Audit logs track all cross-org access attempts |
| Privilege escalation | RBAC enforced at API layer; never grant admin to wrong org |
| Backup exposure | Encrypted backups; access controls on backup storage |

---

## 5. MULTI-BRANCH ARCHITECTURE

### Branch Hierarchy

```
Organization (Tenant)
├── Branch 1 (Delhi)
│   ├── Inventory
│   ├── Employees
│   ├── Sales
│   └── Purchases
├── Branch 2 (Mumbai)
│   ├── Inventory
│   ├── Employees
│   ├── Sales
│   └── Purchases
└── Head Office (Admin)
    └── Organization-wide reports
```

### Branch-Level Data Ownership

**Branch-Specific:**
- Inventory (stock by branch)
- Sales (POS transactions)
- Purchases (supplier orders)
- Employees (staff)
- Expenses (branch costs)
- Stock transfers (in/out)

**Organization-Wide (Shared):**
- Master medicines catalog
- Supplier list
- Customer list (optional: branch-specific customers)
- Subscription
- Settings

### Branch Table Design
```sql
CREATE TABLE branches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL,
  address TEXT,
  phone VARCHAR(20),
  email VARCHAR(100),
  manager_id UUID REFERENCES users(id),
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, code)
);
```

### Multi-Branch Inventory

**Key Rule:** Each branch has independent inventory

```sql
CREATE TABLE inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  branch_id UUID NOT NULL REFERENCES branches(id),
  batch_id UUID NOT NULL REFERENCES batches(id),
  quantity_on_hand INT NOT NULL DEFAULT 0,
  quantity_reserved INT NOT NULL DEFAULT 0,
  quantity_available INT GENERATED ALWAYS AS 
    (quantity_on_hand - quantity_reserved) STORED,
  last_counted_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, branch_id, batch_id),
  FOREIGN KEY (organization_id) REFERENCES organizations(id)
);
```

### Multi-Branch Reports

**Branch-Specific Report:**
```sql
SELECT 
  b.name as branch,
  COUNT(DISTINCT s.id) as total_sales,
  SUM(s.total_amount) as total_revenue,
  SUM(s.profit) as total_profit
FROM sales s
JOIN branches b ON s.branch_id = b.id
WHERE s.organization_id = $1 AND s.branch_id = $2
GROUP BY b.id, b.name;
```

**Organization-Wide Report:**
```sql
SELECT 
  b.name as branch,
  COUNT(DISTINCT s.id) as total_sales,
  SUM(s.total_amount) as total_revenue,
  SUM(s.profit) as total_profit
FROM sales s
JOIN branches b ON s.branch_id = b.id
WHERE s.organization_id = $1
GROUP BY b.id, b.name
ORDER BY total_revenue DESC;
```

### Stock Transfer Between Branches

```sql
CREATE TABLE stock_transfers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  from_branch_id UUID NOT NULL REFERENCES branches(id),
  to_branch_id UUID NOT NULL REFERENCES branches(id),
  status VARCHAR(50) NOT NULL DEFAULT 'requested',
  requested_by UUID NOT NULL REFERENCES users(id),
  requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  approved_by UUID REFERENCES users(id),
  approved_at TIMESTAMP,
  dispatched_at TIMESTAMP,
  received_at TIMESTAMP,
  cancelled_at TIMESTAMP,
  
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  CHECK (from_branch_id != to_branch_id)
);

CREATE TABLE stock_transfer_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id UUID NOT NULL REFERENCES stock_transfers(id),
  batch_id UUID NOT NULL REFERENCES batches(id),
  requested_quantity INT NOT NULL,
  dispatched_quantity INT,
  received_quantity INT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 6. USER & RBAC ARCHITECTURE

### Role Hierarchy

```
SUPER_ADMIN (System-wide - Buildify staff only)
  └─ Can access all organizations, manage subscriptions

OWNER (Organization-wide)
  └─ Full access to organization, all branches, all features

BRANCH_MANAGER (Branch-specific)
  └─ Full access to assigned branch(es)

PHARMACIST (Branch-specific)
  └─ Medicine management, inventory, can approve returns

CASHIER (Branch-specific)
  └─ POS access, limited to sales transactions

INVENTORY_MANAGER (Branch-specific)
  └─ Inventory management, stock transfers, purchases

ACCOUNTANT (Organization-wide)
  └─ Financial reports, payments, no transaction modification
```

### User Tables

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100),
  last_name VARCHAR(100),
  phone VARCHAR(20),
  is_active BOOLEAN DEFAULT true,
  last_login_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE organization_users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  user_id UUID NOT NULL REFERENCES users(id),
  is_owner BOOLEAN DEFAULT false,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, user_id)
);

CREATE TABLE roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(50) NOT NULL UNIQUE,
  description TEXT,
  is_system_role BOOLEAN DEFAULT false,
  organization_id UUID REFERENCES organizations(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  -- System roles (SUPER_ADMIN, OWNER, etc.) have organization_id = NULL
  CHECK (is_system_role = false OR organization_id IS NULL)
);

CREATE TABLE permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code VARCHAR(100) NOT NULL UNIQUE,
  description TEXT,
  category VARCHAR(50), -- 'medicines', 'sales', 'purchases', etc.
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE role_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id UUID NOT NULL REFERENCES roles(id),
  permission_id UUID NOT NULL REFERENCES permissions(id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(role_id, permission_id)
);

CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  user_id UUID NOT NULL REFERENCES users(id),
  role_id UUID NOT NULL REFERENCES roles(id),
  assigned_by UUID NOT NULL REFERENCES users(id),
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, user_id, role_id)
);

CREATE TABLE user_branch_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id),
  user_id UUID NOT NULL REFERENCES users(id),
  branch_id UUID NOT NULL REFERENCES branches(id),
  assigned_by UUID NOT NULL REFERENCES users(id),
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(user_id, branch_id)
);
```

### Permission Matrix

| Permission | SUPER_ADMIN | OWNER | BRANCH_MGR | PHARMACIST | CASHIER | INV_MGR | ACCOUNTANT |
|-----------|-------------|-------|-----------|-----------|---------|---------|-----------|
| create_medicine | ✓ | ✓ | ✗ | ✓ | ✗ | ✗ | ✗ |
| edit_medicine | ✓ | ✓ | ✗ | ✓ | ✗ | ✗ | ✗ |
| view_inventory | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| create_sale | ✓ | ✓ | ✓ | ✗ | ✓ | ✗ | ✗ |
| create_purchase | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ | ✗ |
| view_reports | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✓ |
| manage_users | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |
| view_audit_logs | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ | ✗ |

### RBAC Enforcement (Backend)

```typescript
// Middleware to check permissions
async function requirePermission(permission: string) {
  return async (req, res, next) => {
    const userId = req.user.id;
    const organizationId = req.user.organization_id;
    
    // Get user's roles
    const roles = await db.query(
      `SELECT r.id FROM user_roles ur
       JOIN roles r ON ur.role_id = r.id
       WHERE ur.user_id = $1 AND ur.organization_id = $2`,
      [userId, organizationId]
    );
    
    // Check if any role has this permission
    const hasPermission = await db.query(
      `SELECT 1 FROM role_permissions rp
       JOIN permissions p ON rp.permission_id = p.id
       WHERE rp.role_id = ANY($1) AND p.code = $2`,
      [roles.map(r => r.id), permission]
    );
    
    if (!hasPermission.rows.length) {
      return res.status(403).json({ error: 'Insufficient permissions' });
    }
    
    next();
  };
}

// Usage
app.post('/medicines', requirePermission('create_medicine'), createMedicine);
```

---

## 7. COMPLETE DATABASE SCHEMA

### Core Tables

#### organizations
```sql
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
  subscription_plan_id UUID REFERENCES subscription_plans(id),
  max_branches INT DEFAULT 1,
  max_users INT DEFAULT 5,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  INDEX idx_org_slug (slug),
  INDEX idx_org_status (subscription_status)
);
```

#### branches
```sql
CREATE TABLE branches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  code VARCHAR(50) NOT NULL,
  address TEXT,
  phone VARCHAR(20),
  email VARCHAR(100),
  manager_id UUID REFERENCES users(id),
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
```

#### users
```sql
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
```

#### organization_users
```sql
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
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_org_user_org (organization_id),
  INDEX idx_org_user_user (user_id)
);
```

#### roles
```sql
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
```

#### permissions
```sql
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
```

#### role_permissions
```sql
CREATE TABLE role_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(role_id, permission_id),
  INDEX idx_role_perm_role (role_id),
  INDEX idx_role_perm_perm (permission_id)
);
```

#### user_roles
```sql
CREATE TABLE user_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES users(id),
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(organization_id, user_id, role_id),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_user_role_org (organization_id),
  INDEX idx_user_role_user (user_id),
  INDEX idx_user_role_role (role_id)
);
```

#### user_branch_access
```sql
CREATE TABLE user_branch_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  assigned_by UUID NOT NULL REFERENCES users(id),
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  
  UNIQUE(user_id, branch_id),
  FOREIGN KEY (organization_id) REFERENCES organizations(id),
  INDEX idx_branch_access_user (user_id),
  INDEX idx_branch_access_branch (branch_id),
  INDEX idx_branch_access_org (organization_id)
);
```

### Medicines & Categories

#### categories
```sql
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
```

#### manufacturers
```sql
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
```

#### medicines
```sql
CREATE TABLE medicines (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  generic_name VARCHAR(255),
  brand_name VARCHAR(255),
  category_id UUID NOT NULL REFERENCES categories(id),
  manufacturer_id UUID NOT NULL REFERENCES manufacturers(id),
  strength VARCHAR(100),
  dosage_form VARCHAR(100), -- 'tablet', 'capsule', 'liquid', etc.
  pack_size INT, -- quantity per pack
  unit VARCHAR(50), -- 'strip', 'bottle', 'box', etc.
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
  INDEX idx_med_status (status),
  FULLTEXT INDEX idx_med_search (name, generic_name, brand_name)
);
```

### Suppliers & Customers

#### suppliers
```sql
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
  INDEX idx_supp_active (is_active){