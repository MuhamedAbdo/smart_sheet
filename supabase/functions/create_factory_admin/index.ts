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
    if (!authHeader) {
      throw new Error('Unauthorized: Missing auth header')
    }
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

    if (user.email !== 'mohamedabdo9999933@gmail.com') {
      throw new Error(`Forbidden: Super Admin access only. Current user is: ${user.email}`)
    }

    const body = await req.json()
    console.log('✅ Body received successfully')

    const { factoryName, adminEmail, adminPassword } = body
    if (!factoryName || !adminEmail || !adminPassword) {
      throw new Error('Missing required fields')
    }

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)
    const factoryId = `FACT-${Math.floor(1000 + Math.random() * 9000)}`

    console.log(`⏳ Attempting to create factory: ${factoryName}`)
    const { error: factoryError } = await supabaseAdmin
      .from('factories')
      .insert([{ factory_id: factoryId, name: factoryName }])

    if (factoryError) throw new Error(`Factory creation failed: ${factoryError.message}`)
    console.log('✅ Factory created successfully')

    console.log(`⏳ Attempting to create admin account for: ${adminEmail}`)
    const { data: authData, error: createAuthError } = await supabaseAdmin.auth.admin.createUser({
      email: adminEmail,
      password: adminPassword,
      email_confirm: true,
    })

    if (createAuthError) throw new Error(`Admin account creation failed: ${createAuthError.message}`)
    console.log('✅ Admin user created successfully')

    const newAdminUid = authData.user.id

    console.log(`⏳ Attempting to link profile for UID: ${newAdminUid}`)
    const { error: profileError } = await supabaseAdmin
      .from('profiles')
      .insert([
        {
          id: newAdminUid,
          factory_id: factoryId,
          role: 'admin',
        },
      ])

    if (profileError) throw new Error(`Profile creation failed: ${profileError.message}`)
    console.log('✅ Profile linked successfully! All done.')

    return new Response(
      JSON.stringify({
        message: 'Factory and Admin account created successfully 🎉',
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
