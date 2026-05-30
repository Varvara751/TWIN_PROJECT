/// <reference lib="deno.ns" />
import { createClient, type SupabaseClient } from '@supabase/supabase-js';

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

async function removeStorageFolder(
  supabase: SupabaseClient,
  bucket: string,
  folder: string,
) {
  const { data: files } = await supabase.storage.from(bucket).list(folder);
  if (!files || files.length === 0) return;

  const paths = files.map((file) => `${folder}/${file.name}`);
  await supabase.storage.from(bucket).remove(paths);
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
    await removeStorageFolder(supabase, 'avatars', `avatars/${user.id}`);
    await removeStorageFolder(supabase, 'avatars', `profile_photos/${user.id}`);
  } catch (error) {
    console.warn('Storage cleanup failed:', error);
  }

  await supabase.from('profile_likes').delete().eq('target_user_id', user.id);
  await supabase.from('profile_likes').delete().eq('source_user_id', user.id);
  await supabase.from('profile_photo_likes').delete().eq('source_user_id', user.id);
  await supabase.from('profile_follows').delete().eq('follower_id', user.id);
  await supabase.from('profile_follows').delete().eq('following_id', user.id);
  await supabase.from('message_deletions').delete().eq('user_id', user.id);
  await supabase.from('chat_deletions').delete().eq('user_id', user.id);
  await supabase.from('chat_blocks').delete().eq('blocker_id', user.id);
  await supabase.from('chat_blocks').delete().eq('blocked_id', user.id);
  await supabase.from('profile_photos').delete().eq('user_id', user.id);

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
