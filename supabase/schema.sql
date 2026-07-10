-- ============================================================
-- SETUP ULANG TABEL gifts - Birthdayfy
-- Jalankan SEKALI di Supabase Dashboard > SQL Editor > Run
-- (Project: jnrkcyzwxsolazbxjpwy.supabase.co)
-- Aman dijalankan berulang kali (idempoten).
-- ============================================================

-- 1) Buat tabel jika belum ada (dengan id & created_at)
CREATE TABLE IF NOT EXISTS public.gifts (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at  timestamptz DEFAULT now()
);

-- 2) Tambah kolom data hanya jika belum ada
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'gifts' AND column_name = 'name') THEN
        ALTER TABLE public.gifts ADD COLUMN "name" text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'gifts' AND column_name = 'photos') THEN
        ALTER TABLE public.gifts ADD COLUMN "photos" jsonb;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'gifts' AND column_name = 'spotifyUrl') THEN
        ALTER TABLE public.gifts ADD COLUMN "spotifyUrl" text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'gifts' AND column_name = 'letter') THEN
        ALTER TABLE public.gifts ADD COLUMN "letter" text;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'gifts' AND column_name = 'updatedAt') THEN
        ALTER TABLE public.gifts ADD COLUMN "updatedAt" timestamptz;
    END IF;
END $$;

-- 3) Pastikan id selalu punya default (jika tabel dibuat manual)
--    Lewati kalau id sudah jadi identity column (tidak boleh di-SET DEFAULT).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'gifts' AND column_name = 'id'
          AND column_default IS NOT NULL
    ) THEN
        IF NOT EXISTS (
            SELECT 1 FROM pg_attribute a
            JOIN pg_class c ON c.oid = a.attrelid
            WHERE c.relname = 'gifts' AND a.attname = 'id' AND a.attidentity <> ''
        ) THEN
            ALTER TABLE public.gifts ALTER COLUMN id SET DEFAULT gen_random_uuid();
        END IF;
    END IF;
END $$;

-- 3b) Bersihkan duplikat name (simpan row terbaru) sebelum pasang constraint unik
DELETE FROM public.gifts a
USING public.gifts b
WHERE a.ctid < b.ctid
  AND lower(a."name") = lower(b."name");

-- 3c) Pastikan kolom name unik agar "nama sama = gift sama" tidak bentrok
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE table_name = 'gifts' AND constraint_name = 'gifts_name_unique'
    ) THEN
        ALTER TABLE public.gifts ADD CONSTRAINT gifts_name_unique UNIQUE ("name");
    END IF;
END $$;

-- 4) Aktifkan Row Level Security agar bisa diakses dari client (anon key)
ALTER TABLE public.gifts ENABLE ROW LEVEL SECURITY;

-- Baca: bebas (user.html cari gift by name pakai anon key)
DROP POLICY IF EXISTS "Public read gifts" ON public.gifts;
CREATE POLICY "Public read gifts" ON public.gifts
    FOR SELECT USING (true);

-- Tulis: HANYA user yang sudah login (admin). user.html tetap cuma bisa baca.
DROP POLICY IF EXISTS "Admin insert gifts" ON public.gifts;
CREATE POLICY "Admin insert gifts" ON public.gifts
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admin update gifts" ON public.gifts;
CREATE POLICY "Admin update gifts" ON public.gifts
    FOR UPDATE USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Admin delete gifts" ON public.gifts;
CREATE POLICY "Admin delete gifts" ON public.gifts
    FOR DELETE USING (auth.role() = 'authenticated');
