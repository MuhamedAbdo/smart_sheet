-- ==============================================================
-- 1. جعل حقل factory_id اختيارياً (Nullable) في جدول pairing_codes
-- ==============================================================
ALTER TABLE public.pairing_codes 
ALTER COLUMN factory_id DROP NOT NULL;

-- التأكد من وجود عمود is_used بقيمة افتراضية false
ALTER TABLE public.pairing_codes 
ADD COLUMN IF NOT EXISTS is_used BOOLEAN DEFAULT false;

-- التأكد من وجود عمود expires_at
ALTER TABLE public.pairing_codes 
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

-- ==============================================================
-- 2. دالة التحقق من كود الدخول العام (validate_invitation_code)
-- تتحقق فقط من: (تطابق الكود + is_used = false + الصلاحية expires_at)
-- وتحديث is_used = true لمنع إعادة استخدامه
-- ==============================================================
-- إزالة أي نسخ سابقة للدالة لتجنب تعارض المعاملات (Overload conflict)
DROP FUNCTION IF EXISTS public.validate_invitation_code(text, text);
DROP FUNCTION IF EXISTS public.validate_invitation_code(text);

CREATE OR REPLACE FUNCTION public.validate_invitation_code(p_code text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_found boolean := false;
BEGIN
    p_code := trim(p_code);

    -- التحقق من وجود الكود وتطابقه وأنه غير مستخدم وصالح زمنياً
    IF EXISTS (
        SELECT 1 
        FROM public.pairing_codes
        WHERE code = p_code
          AND (is_used IS FALSE OR is_used IS NULL)
          AND (expires_at IS NULL OR expires_at > (now() AT TIME ZONE 'utc'))
    ) THEN
        -- تحديث حالة الكود إلى مستخدم لمنع استخدامه مرة أخرى
        UPDATE public.pairing_codes
        SET is_used = true
        WHERE code = p_code;
        
        v_found := true;
    END IF;

    RETURN v_found;
END;
$$;

-- منح الصلاحيات لدالة التحقق
GRANT EXECUTE ON FUNCTION public.validate_invitation_code(text) TO anon, authenticated, service_role;

-- ==============================================================
-- 3. دالة إنشاء وتفعيل كود الدعوة (create_invitation) كود عام
-- ==============================================================
DROP FUNCTION IF EXISTS public.create_invitation(text);

CREATE OR REPLACE FUNCTION public.create_invitation(new_code text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    INSERT INTO public.pairing_codes (code, factory_id, is_used, expires_at)
    VALUES (
        trim(new_code),
        NULL,
        false,
        (now() AT TIME ZONE 'utc' + interval '30 days')
    )
    ON CONFLICT (code) DO UPDATE
    SET is_used = false,
        expires_at = (now() AT TIME ZONE 'utc' + interval '30 days');
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_invitation(text) TO anon, authenticated, service_role;

