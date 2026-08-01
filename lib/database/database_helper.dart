import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance =
      DatabaseHelper._internal(); //one database manager

  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'mediqueue.db');

    return await openDatabase(path, version: 1, onCreate: _createDatabase);
  }

  Future<void> _createDatabase(Database db, int version) async {
    // USERS TABLE
    await db.execute('''
      CREATE TABLE users (
        user_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        mobile TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL
        

      )
    ''');

    // PATIENTS TABLE
    await db.execute('''
      CREATE TABLE patients (
        patient_id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        date_of_birth TEXT,
        gender TEXT,
        patient_mobile TEXT NOT NULL,
        relationship TEXT,
        FOREIGN KEY (user_id) REFERENCES users(user_id)
      )
    ''');

    // DOCTORS TABLE
    await db.execute('''
      CREATE TABLE doctors (
        doctor_id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        specialization TEXT NOT NULL
      )
    ''');

    // DOCTOR AVAILABILITY TABLE
    await db.execute('''
      CREATE TABLE doctor_availability (
        availability_id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctor_id INTEGER NOT NULL,
        duty_date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        duty_status TEXT NOT NULL,
        delay_minutes INTEGER DEFAULT 0,
        FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
      )
    ''');

    // BOOKINGS TABLE
    await db.execute('''
      CREATE TABLE bookings (
        booking_id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        doctor_id INTEGER NOT NULL,
        availability_id INTEGER NOT NULL,
        booking_date TEXT NOT NULL,
        queue_number INTEGER NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
        FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
        FOREIGN KEY (availability_id) 
          REFERENCES doctor_availability(availability_id)
      )
    ''');
  }
}
