import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/main_navigation.dart';
import 'utils/theme.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'utils/secrets_manager.dart';
import 'dart:convert';
import 'package:google_secret_manager/google_secret_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Configure Firestore settings to disable caching
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  final jsonData = {
    "type": "service_account",
    "project_id": "cvsr-296e3",
    "private_key_id": "93031275b94653843eb78705d076db7cfddf4171",
    "private_key":
        "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQDk6TPQYC5uIHcH\nyJSBzLW5oXAuJG8DcALvFYCGwypRr32AOeuklkdqNxp8fM5lRXPi5KP0Cxq4vK/4\nbmv2rPtWoDLqJJCjChQFu8+Z1Pcl7ZLhlNtGtj1JdPelJKD9T1NTLLfe5cWLeuno\nQ4rkyTxKz3sS5tFaIWVv5P/1NNOwHuZx/oHbqA0ki2MQa5tK6bZao4H9XfoQFa5O\nq7yhVpcFVHPeBH4NUh3ozPLL1UhK+RhJ80J5W04GPAVZGmI0j2aUX9WeQoiIrV+O\n+Kp+eR+SQ/D1CTrtsYkVCwlOrngg99ORHaD7weXVUANvGLBmeOM69V/prwMD706L\n5g6Mgrb/AgMBAAECggEAGDQADSbeQeP03JcnUey5xNLTmvgHNNnXCuhpxStFgjWH\n6NLhnhlgRlQP3NxlW5fS/556fLHf4BXd6pU3nRv/xyemZSil56yHyW4Tg98HSAoC\niboaJTPc7wi1q88KUT4zP+FuijFz3aI1W8rTGLWeRlqsV1HzDhCR5RmAEVvF4M0b\nDM4SmOm/fwuiY979IboLfzTP45pQJBhrWphePpXCzcTiy5XpaBsLia2JqhX7vlTY\n3GJapN7zh5cyGQs2WQxeFJhzRHU/khg/p+yvFC74Bm7tZ+Xj+XzZuHcwG4cFaU4/\nIlzPFXoKzoVbRgBd1p+nyVDqu28eYjn9QnD2SO0zoQKBgQD5KQJR1mNoR89Boxw5\nYylw5GFhPJWzX/H5XIJ5MDe7bf44l8wVZUJQmZDE//JkC9il/ZzpZDCMExYj36NZ\nHflCaruyPhKFqgDzaQXdF08mTp5noZwQM8zJ1JpjXl+Xgz7DwjzFXWsMLLlrwJzV\nTVZIJwSyXoDdl2IaoKHvIiOZXQKBgQDrMePsxR6zBQMCwb0YSR4dOGCagaYyv2Od\nyAFuVgcc4H+KBbbFb37YalZPgO1EVvJFbUV87DkTxh92xS1dwVEpTJ7GJM+ov/FF\neS8VShMcFoPAJT9PsYnLa1xIcWY9p5Zd9b72oGpx5dxTlHBiZrZkj7PXTXB6/J70\ngau8upWgCwKBgQCASPQPzNFr7KUyh1fN2FeK75uP5BCzxW+h01a+LOxVDYH6A3Yp\ngfRN6XNXauyTRGIsvNKgfFxekqkwmUHSbZNb9fZkBH+m4GwS530EY6716z613siq\nsvD67gL7rKiNKx8SzZxahgnKv/BMIWTeki4dgjFx4SR6cyooyZH2vN4VZQKBgBMU\n0B4UfAIgJPdjSnke7X+HZGcEn7w8RNO3N06BUkBoglBrWEG6Yvsh3XDDz/wcZbl2\nPQ3+iD7vcvwK0TxrA6+rFLKUp/hT4jo1s7kxck10EipTm0hW6gwD4M/Ly3SzFQL4\nfg66QwiMkoyBXYDOPnv4IKoWEUsZFbhWkN1V8e+zAoGACeEOYLcP+hylnDMdzMtu\nY3VE8hDgKqGxrWk2+7E/keW25KvsVQU1orGppW47qumL42rTe9uMDJHP97BFqAid\ner0fmeazcppfLtTZgS5nNSU6l43rVdfuaOM4SOvDIOq07mrnLmcSZb3cWJ/bMn7F\n9snmJvvxKcZe/aoQB7EkkR0=\n-----END PRIVATE KEY-----\n",
    "client_email": "flutter-app@cvsr-296e3.iam.gserviceaccount.com",
    "client_id": "104922267220530837784",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://oauth2.googleapis.com/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url":
        "https://www.googleapis.com/robot/v1/metadata/x509/flutter-app%40cvsr-296e3.iam.gserviceaccount.com",
    "universe_domain": "googleapis.com",
  };

  final jsonString = jsonEncode(jsonData);

  await GoogleSecretManagerInitializer.initViaServiceAccountJson(jsonString);

  // Fetch and print the Places API key
  try {
    final placesApiKey = await SecretsManager().getSecret(
      'CVS_App_Places_API_Key',
    );
    print('Places API Key: $placesApiKey');

    final stripePK = await SecretsManager().getSecret('CVS_App_Stripe_PK');
    print('Stripe PK: $stripePK');

    final stripeSK = await SecretsManager().getSecret('CVS_App_Stripe_SK');
    print('Stripe SK: $stripeSK');
  } catch (e) {
    print('Error fetching Places API Key: $e');
  }

  // set the publishable key for Stripe - this is mandatory
  Stripe.publishableKey = await SecretsManager().getSecret('CVS_App_Stripe_PK');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CVS Recycling',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const MainNavigation(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If the snapshot has user data, then they're already signed in
        if (snapshot.hasData) {
          return const MainNavigation();
        }
        // Otherwise, they're not signed in. Show the login page
        return const LoginPage();
      },
    );
  }
}
