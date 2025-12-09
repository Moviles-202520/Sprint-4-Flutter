import 'package:flutter/material.dart';
// imports de repositorios/screens movidos a sus respectivos widgets
import 'package:punto_neutro/presentation/screens/PuntoNeutroApp.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/image_cache_service.dart';
import 'data/workers/notification_sync_worker.dart';
import 'data/workers/bookmark_sync_worker.dart';
import 'data/services/reading_history_local_storage.dart';

/// Inicialización CRÍTICA para poder mostrar el primer frame rápido.
Future<void> _initializeCriticalServices() async {
  // ⚠️ SKIP: Reading History Database (SQLite no funciona en web)
  // Si en algún momento la app depende sí o sí de esto para el home,
  // se puede mover aquí y dejarlo inicializado antes del primer frame.
  // try {
  //   await ReadingHistoryLocalStorage().database;
  //   print('✅ Reading History Database inicializada');
  // } catch (e, st) {
  //   print('! Error inicializando Reading History Database: $e');
  //   print(st);
  // }

  // Inicializar Hive solo con lo necesario para el tema
  try {
    await Hive.initFlutter();
    await Hive.openBox<dynamic>('theme_settings'); // Theme box (crítico para UI)
    print('✅ Hive inicializado (theme_settings)');
  } catch (e, st) {
    print('⚠️ Error inicializando Hive crítico: $e');
    print(st);
  }

  // ✅ INICIALIZAR SUPABASE (crítico para la app)
  await Supabase.initialize(
    url: 'https://oikdnxujjmkbewdhpyor.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9pa2RueHVqam1rYmV3ZGhweW9yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTk0MDU0MjksImV4cCI6MjA3NDk4MTQyOX0.htw3cdc-wFcBjKKPP4aEC9K9xBEnvPULMToP_PIuaLI',
  );
}

/// Inicialización DIFERIDA: cosas pesadas que no son necesarias
/// para mostrar el primer frame (se ejecutan después de runApp).
Future<void> _initializeDeferredServices() async {
  // Inicializar y abrir cajas pesadas de Hive para cache offline
  try {
    // Estas cajas no son necesarias para que arranque la app, así que
    // se abren después del primer frame.
    await Hive.openBox<dynamic>('news_cache');
    await Hive.openBox<dynamic>('comments_cache');
    await Hive.openBox<dynamic>('ratings_cache');

    await ImageCacheService.ensureBoxOpened();

    // Las "pending" se almacenan como keys dentro de las cajas de comments/ratings
    print('✅ Hive cajas de cache abiertas (deferred)');
  } catch (e, st) {
    print('⚠️ Error inicializando Hive (deferred): $e');
    print(st);
  }

  // ⚠️ SKIP: Notification Sync Worker (WorkManager no funciona en web)
  // ✅ INICIALIZAR NOTIFICATION SYNC WORKER (B.4 - Eventual Connectivity)
  // Cuando estés en Android/iOS (no web) y tengas WorkManager estable,
  // puedes mover esta inicialización aquí para no bloquear el launch.
  //
  // try {
  //   await NotificationSyncWorker.initialize();
  //   await NotificationSyncWorker.registerPeriodicSync();
  //   print('✅ Notification Sync Worker registrado (deferred)');
  // } catch (e, st) {
  //   print('! Error inicializando Notification Sync Worker: $e');
  //   print(st);
  // }

  // ⚠️ SKIP: Bookmark Sync Worker (WorkManager no funciona en web)
  // ✅ INICIALIZAR BOOKMARK SYNC WORKER (C.3 - LWW Reconciliation)
  // try {
  //   await BookmarkSyncWorker.initialize();
  //   await BookmarkSyncWorker.registerPeriodicSync();
  //   print('✅ Bookmark Sync Worker registrado (deferred)');
  // } catch (e, st) {
  //   print('! Error inicializando Bookmark Sync Worker: $e');
  //   print(st);
  // }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Inicialización crítica (bloqueante, pero mínima)
  await _initializeCriticalServices();

  // 2) Lanzar la app lo antes posible
  runApp(const PuntoNeutroApp());

  // 3) Inicialización diferida después del primer frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    // No esperamos el Future explícitamente; se inicializa en segundo plano
    _initializeDeferredServices();
  });
}

// ------------------------------------------------------
// Todo lo de abajo es el boilerplate que ya tenías
// (el contador de ejemplo de Flutter). Lo dejo igual.
// ------------------------------------------------------

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
