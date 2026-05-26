# Supabase setup

Run these commands before testing full account deletion:

```powershell
supabase db push
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
supabase functions deploy delete-account
```

The Flutter app calls the `delete-account` Edge Function. If the function is
not deployed, Supabase returns `FunctionException(status: 404)`.
