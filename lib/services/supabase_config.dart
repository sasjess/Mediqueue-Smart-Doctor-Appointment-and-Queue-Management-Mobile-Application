import 'package:supabase_flutter/supabase_flutter.dart';

// Set values directly or use fallback defaults
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://aginmwptyqgzqxeerabu.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_18KZIVgdhC5VS1U5MeqK4w_ijDuDxW0',
);

Future<void> initializeSupabase() async {
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'Supabase is not configured. Pass SUPABASE_URL and SUPABASE_ANON_KEY via --dart-define or set them here.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey, // Note: standard parameter is `anonKey`
    authOptions: const FlutterAuthClientOptions(
      autoRefreshToken: true,
    ),
  );
}