// lib/services/realtime_service.dart
// Firebase real-time listeners for live updates

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing real-time Firebase listeners
class RealtimeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Stream controllers for different data types
  static Stream<QuerySnapshot>? _studentsStream;
  static Stream<QuerySnapshot>? _paymentsStream;
  static Stream<QuerySnapshot>? _callsStream;
  static Stream<QuerySnapshot>? _remindersStream;

  /// Listen to students collection changes
  static Stream<QuerySnapshot>? watchStudents({String? schoolId}) {
    try {
      Query query = _firestore.collection('students');
      if (schoolId != null) {
        query = query.where('school_id', isEqualTo: schoolId);
      }
      _studentsStream = query.snapshots();
      return _studentsStream;
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up students stream: $e');
      }
      return null;
    }
  }

  /// Listen to payments collection changes
  static Stream<QuerySnapshot>? watchPayments({String? schoolId, String? studentId}) {
    try {
      Query query = _firestore.collection('payments');
      if (schoolId != null) {
        query = query.where('school_id', isEqualTo: schoolId);
      }
      if (studentId != null) {
        query = query.where('student_id', isEqualTo: studentId);
      }
      _paymentsStream = query.snapshots();
      return _paymentsStream;
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up payments stream: $e');
      }
      return null;
    }
  }

  /// Listen to calls collection changes
  static Stream<QuerySnapshot>? watchCalls({String? schoolId, String? studentId}) {
    try {
      Query query = _firestore.collection('calls');
      if (schoolId != null) {
        query = query.where('school_id', isEqualTo: schoolId);
      }
      if (studentId != null) {
        query = query.where('student_id', isEqualTo: studentId);
      }
      query = query.orderBy('created_at', descending: true);
      _callsStream = query.snapshots();
      return _callsStream;
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up calls stream: $e');
      }
      return null;
    }
  }

  /// Listen to reminders collection changes
  static Stream<QuerySnapshot>? watchReminders({String? schoolId, String? studentId}) {
    try {
      Query query = _firestore.collection('reminders');
      if (schoolId != null) {
        query = query.where('school_id', isEqualTo: schoolId);
      }
      if (studentId != null) {
        query = query.where('student_id', isEqualTo: studentId);
      }
      query = query.orderBy('scheduled_at', descending: false);
      _remindersStream = query.snapshots();
      return _remindersStream;
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up reminders stream: $e');
      }
      return null;
    }
  }

  /// Dispose all streams (call when app closes or when switching contexts)
  static void dispose() {
    // Streams will be automatically disposed when listeners are removed
    _studentsStream = null;
    _paymentsStream = null;
    _callsStream = null;
    _remindersStream = null;
  }
}
