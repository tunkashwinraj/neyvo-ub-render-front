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

  /// Listen to students collection changes (accountId = account id).
  static Stream<QuerySnapshot>? watchStudents({String? accountId}) {
    try {
      Query query = _firestore.collection('students');
      if (accountId != null) {
        query = query.where('account_id', isEqualTo: accountId);
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

  /// Listen to payments collection changes (accountId = account id).
  static Stream<QuerySnapshot>? watchPayments({String? accountId, String? studentId}) {
    try {
      Query query = _firestore.collection('payments');
      if (accountId != null) {
        query = query.where('account_id', isEqualTo: accountId);
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

  /// Listen to calls collection changes (accountId = account id).
  static Stream<QuerySnapshot>? watchCalls({String? accountId, String? studentId}) {
    try {
      Query query = _firestore.collection('calls');
      if (accountId != null) {
        query = query.where('account_id', isEqualTo: accountId);
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

  /// Listen to reminders collection changes (accountId = account id).
  static Stream<QuerySnapshot>? watchReminders({String? accountId, String? studentId}) {
    try {
      Query query = _firestore.collection('reminders');
      if (accountId != null) {
        query = query.where('account_id', isEqualTo: accountId);
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
