-- ==============================================================
-- إنشاء جدول سجل التعديلات (item_edit_history) لأصناف العملاء
-- ==============================================================

CREATE TABLE IF NOT EXISTS public.item_edit_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id TEXT NOT NULL REFERENCES public.customers(sync_id) ON DELETE CASCADE,
    factory_id TEXT,
    edited_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    old_data JSONB NOT NULL,
    new_data JSONB NOT NULL
);

-- التعليق على الجدول والأعمدة لتوثيق الغرض
COMMENT ON TABLE public.item_edit_history IS 'جدول تتبع وتخزين سجل التعديلات السابقة لأصناف العملاء (بيانات نصية ورقمية فقط مع استثناء الصور)';
COMMENT ON COLUMN public.item_edit_history.id IS 'المعرف الأساسي لسجل التعديل';
COMMENT ON COLUMN public.item_edit_history.item_id IS 'المعرف الفريد للصنف (مرتبط بـ sync_id في جدول customers)';
COMMENT ON COLUMN public.item_edit_history.edited_at IS 'تاريخ ووقت التعديل';
COMMENT ON COLUMN public.item_edit_history.old_data IS 'بيانات الصنف قبل التعديل بصيغة JSONB (نصية ورقمية فقط)';
COMMENT ON COLUMN public.item_edit_history.new_data IS 'البيانات الجديدة المدخلة بصيغة JSONB (نصية ورقمية فقط)';

-- إنشاء الفهارس (Indexes) لسرعة الاستعلام والترتيب
CREATE INDEX IF NOT EXISTS idx_item_edit_history_item_id ON public.item_edit_history(item_id);
CREATE INDEX IF NOT EXISTS idx_item_edit_history_edited_at ON public.item_edit_history(edited_at DESC);
CREATE INDEX IF NOT EXISTS idx_item_edit_history_factory_id ON public.item_edit_history(factory_id);

-- تفعيل سياسات الأمان على مستوى الصفوف (Row Level Security - RLS)
ALTER TABLE public.item_edit_history ENABLE ROW LEVEL SECURITY;

-- سياسة السماح بالقراءة
DROP POLICY IF EXISTS "Allow read access to item_edit_history" ON public.item_edit_history;
CREATE POLICY "Allow read access to item_edit_history"
ON public.item_edit_history FOR SELECT
USING (true);

-- سياسة السماح بالإدخال
DROP POLICY IF EXISTS "Allow insert access to item_edit_history" ON public.item_edit_history;
CREATE POLICY "Allow insert access to item_edit_history"
ON public.item_edit_history FOR INSERT
WITH CHECK (true);
