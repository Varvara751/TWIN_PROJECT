import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return jsonResponse({ error: 'Method not allowed' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const authHeader = req.headers.get('Authorization') ?? '';
  const jwt = authHeader.replace('Bearer ', '').trim();

  if (!supabaseUrl || !serviceRoleKey) {
    return jsonResponse({ error: 'Server is not configured' }, 500);
  }

  if (!jwt) {
    return jsonResponse({ error: 'Missing authorization token' }, 401);
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
  const user = userData.user;

  if (userError || !user) {
    return jsonResponse({ error: 'Invalid authorization token' }, 401);
  }

  try {
    const avatarFolder = `avatars/${user.id}`;
    const { data: avatarFiles } = await supabase.storage
      .from('avatars')
      .list(avatarFolder);

    if (avatarFiles && avatarFiles.length > 0) {
      const avatarPaths = avatarFiles.map((file) => `${avatarFolder}/${file.name}`);
      await supabase.storage.from('avatars').remove(avatarPaths);
    }
  } catch (error) {
    console.warn('Avatar cleanup failed:', error);
  }

  const { error: profileError } = await supabase
    .from('profil')
    .delete()
    .eq('id', user.id);

  if (profileError) {
    return jsonResponse({ error: profileError.message }, 500);
  }

  const { error: deleteUserError } = await supabase.auth.admin.deleteUser(
    user.id,
  );

  if (deleteUserError) {
    return jsonResponse({ error: deleteUserError.message }, 500);
  }

  return jsonResponse({ ok: true });
});
