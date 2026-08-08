import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: any) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('🔥 --- New Request Received --- 🔥')
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? ''

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) throw new Error('Unauthorized: Missing auth header')
    console.log('✅ Auth header found')

    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    })

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser()
    if (userError || !user) {
      console.error('❌ User Auth Error:', userError)
      throw new Error('Failed to verify user identity')
    }
    console.log('✅ User verified:', user.email)

    // حماية الدالة: السماح فقط لـ Super Admin بتنفيذ هذا الإجراء
    if (user.email !== 'mohamedabdo9999933@gmail.com') {
      throw new Error('Forbidden: Super Admin access only.')
    }

    const body = await req.json()
    console.log('✅ Body received successfully')

    const { factoryName, adminEmail, adminPassword } = body
    if (!factoryName || !adminEmail || !adminPassword) {
      throw new Error('Missing required fields')
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)
    
    // 1. البحث عن المصنع لتجنب التكرار
    console.log(`⏳ Checking if factory exists: ${factoryName}`)
    const { data: existingFactories, error: factorySearchError } = await supabaseAdmin
      .from('factories')
      .select('factory_id')
      .eq('name', factoryName)
      .limit(1)

    if (factorySearchError) {
      throw new Error(`Error checking factory: ${factorySearchError.message}`)
    }

    let factoryId: string
    if (existingFactories && existingFactories.length > 0) {
      const existingFactory = existingFactories[0]
      console.log(`ℹ️ Factory '${factoryName}' already exists. Reusing ID: ${existingFactory.factory_id}`)
      factoryId = existingFactory.factory_id
    } else {
      factoryId = `FACT-${Math.floor(1000 + Math.random() * 9000)}`
      console.log(`⏳ Creating new factory: ${factoryName} with ID: ${factoryId}`)
      const { error: factoryError } = await supabaseAdmin
        .from('factories')
        .insert([{ factory_id: factoryId, name: factoryName }])

      if (factoryError) throw new Error(`Factory creation failed: ${factoryError.message}`)
      console.log('✅ Factory created successfully')
    }

    // 2. جلب أو إنشاء حساب مدير المصنع في Auth
    let newAdminUid: string

    console.log(`⏳ Checking if user exists: ${adminEmail}`)
    const { data: existingUsersData, error: listError } = await supabaseAdmin.auth.admin.listUsers()

    if (listError) throw new Error(`Failed to list users: ${listError.message}`)

    const existingUser = existingUsersData?.users?.find(
      (u: any) => u.email?.toLowerCase() === adminEmail.toLowerCase()
    )

    if (existingUser) {
      console.log(`ℹ️ User already exists (UID: ${existingUser.id}), reusing and updating password...`)
      newAdminUid = existingUser.id

      const { error: updateError } = await supabaseAdmin.auth.admin.updateUserById(
        newAdminUid,
        { password: adminPassword, email_confirm: true }
      )
      if (updateError) throw new Error(`Failed to update existing user: ${updateError.message}`)
      console.log('✅ Existing user password updated successfully')
    } else {
      console.log(`⏳ Creating new admin account for: ${adminEmail}`)
      const { data: authData, error: createAuthError } = await supabaseAdmin.auth.admin.createUser({
        email: adminEmail,
        password: adminPassword,
        email_confirm: true,
      })

      if (createAuthError) throw new Error(`Admin account creation failed: ${createAuthError.message}`)
      newAdminUid = authData.user.id
      console.log('✅ New admin user created successfully')
    }

    // 3. ربط مدير المصنع بجدول profiles 
    console.log(`⏳ Upserting profile for UID: ${newAdminUid}`)
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .upsert([
        {
          id: newAdminUid,
          factory_id: factoryId,
          role: 'admin',
        },
      ])

    if (profileError) throw new Error(`Profile creation failed: ${profileError.message}`)
    console.log('✅ Profile linked successfully')

    // 4. إدراج حساب المدير في جدول العمال (workers)
    console.log(`⏳ Checking if worker record exists for: ${adminEmail}`)
    const { data: existingWorker, error: checkWorkerError } = await supabaseAdmin
      .from('workers')
      .select('id')
      .eq('email', adminEmail)
      .maybeSingle()

    if (checkWorkerError) {
      throw new Error(`Failed to check existing worker: ${checkWorkerError.message}`)
    }

    const workerPayload = {
      email: adminEmail,
      name: 'مدير المصنع',
      factory_id: factoryId,
      department: 'general_mgmt',
      can_add: true,
      can_edit: true,
      can_delete: true,
      can_add_worker: true,
      can_edit_worker: true,
      can_delete_worker: true,
      can_manage_clients_add: true,
      can_manage_clients_edit: true,
      can_manage_clients_delete: true,
      can_read_archive: true,
      can_add_archive: true,
      can_restore_archive: true,
      can_delete_archive: true,
    }

    if (existingWorker) {
      console.log(`⏳ Updating existing worker record (ID: ${existingWorker.id})...`)
      const { error: workerError } = await supabaseAdmin
        .from('workers')
        .update(workerPayload)
        .eq('id', existingWorker.id)
        
      if (workerError) throw new Error(`Worker update failed: ${workerError.message}`)
    } else {
      console.log(`⏳ Inserting new worker record...`)
      const { error: workerError } = await supabaseAdmin
        .from('workers')
        .insert([workerPayload])
        
      if (workerError) throw new Error(`Worker creation failed: ${workerError.message}`)
    }

    console.log('✅ Worker record saved successfully! All done.')

    return new Response(
      JSON.stringify({
        message: 'Factory, Admin profile, and Worker record created successfully 🎉',
        factoryId: factoryId,
        adminEmail: adminEmail,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error: any) {
    console.error('❌ Error Caught:', error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
