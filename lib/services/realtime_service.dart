// lib/services/realtime_service.dart
// Firebase real-time listeners for live updates.
// Uses unified schema: businesses/{accountId}/students|payments|calls|reminders.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing real-time Firebase listeners.
/// Requires [accountId] for all methods; paths are businesses/{accountId}/<subcollection>.
class RealtimeService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<QuerySnapshot>? _studentsStream;
  static Stream<QuerySnapshot>? _paymentsStream;
  static Stream<QuerySnapshot>? _callsStream;
  static Stream<QuerySnapshot>? _remindersStream;

  /// Listen to students: businesses/{accountId}/students.
  static Stream<QuerySnapshot>? watchStudents({String? accountId}) {
    if (accountId == null || accountId.isEmpty) return null;
    try {
      _studentsStream = _firestore
          .collection('businesses')
          .doc(accountId)
          .collection('students')
          .snapshots();
      return _studentsStream;
    } catch (e) {
      if (kDebugMode) {
        print('Error setting up students stream: $e');
      }
      return null;
    }
  }

  /// Listen to payments: businesses/{accountId}/payments. Optional [studentId] filter.
  static Stream<QuerySnapshot>? watchPayments({String? accountId, String? studentId}) {
    if (accountId == null || accountId.isEmpty) return null;
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('businesses')
          .doc(accountId)
          .collection('payments');
      if (studentId != null && studentId.isNotEmpty) {
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

  /// Listen to calls: businesses/{accountId}/calls. Optional [studentId] filter.
  static Stream<QuerySnapshot>? watchCalls({String? accountId, String? studentId}) {
    if (accountId == null || accountId.isEmpty) return null;
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('businesses')
          .doc(accountId)
          .collection('calls');
      if (studentId != null && studentId.isNotEmpty) {
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

  /// Listen to reminders: businesses/{accountId}/reminders. Optional [studentId] filter.
  static Stream<QuerySnapshot>? watchReminders({String? accountId, String? studentId}) {
    if (accountId == null || accountId.isEmpty) return null;
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('businesses')
          .doc(accountId)
          .collection('reminders');
      if (studentId != null && studentId.isNotEmpty) {
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

  /// Dispose all streams (call when app closes or when switching contexts).
  static void dispose() {
    _studentsStream = null;
    _paymentsStream = null;
    _callsStream = null;
    _remindersStream = null;
  }
}
