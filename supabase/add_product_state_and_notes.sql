-- ==============================================================
-- إضافة عمودي "حالة المنتج" و"الملاحظات" لجدول الأصناف (customers) في Supabase
-- ==============================================================
-- الأعمدة متطابقة بالحرف مع المفاتيح المستخدمة في Dart/Flutter:
-- 1. product_state: حالة المنتج (سادة / مطبوع) - القيمة الافتراضية: 'سادة'
-- 2. notes: الملاحظات الخاصة بالصنف - القيمة الافتراضية: نص فارغ ''

ALTER TABLE public.customers 
ADD COLUMN IF NOT EXISTS product_state TEXT DEFAULT 'سادة',
ADD COLUMN IF NOT EXISTS notes TEXT DEFAULT '';

-- توثيق الأعمدة
COMMENT ON COLUMN public.customers.product_state IS 'حالة المنتج (سادة / مطبوع)';
COMMENT ON COLUMN public.customers.notes IS 'ملاحظات الصنف الخاصة بالعميل';

