import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/budget_config.dart';
import '../models/pet_progress.dart';
import '../models/transaction_entry.dart';

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _transactionsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('transactions');
  }

  DocumentReference<Map<String, dynamic>> _budgetRef(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('budget');
  }

  DocumentReference<Map<String, dynamic>> _petRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('settings').doc('pet');
  }

  Stream<List<TransactionEntry>> watchTransactions(String uid) {
    return _transactionsRef(uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          return snapshot.docs.map((
            QueryDocumentSnapshot<Map<String, dynamic>> doc,
          ) {
            return TransactionEntry.fromDoc(doc);
          }).toList();
        });
  }

  Future<void> addTransaction(String uid, TransactionEntry transaction) async {
    await _transactionsRef(uid).doc(transaction.id).set(transaction.toMap());
  }

  Future<void> deleteTransaction(String uid, String transactionId) async {
    await _transactionsRef(uid).doc(transactionId).delete();
  }

  Stream<BudgetConfig> watchBudget(String uid) {
    return _budgetRef(uid).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      return BudgetConfig.fromMap(doc.data());
    });
  }

  Future<void> saveBudget(String uid, BudgetConfig budget) async {
    await _budgetRef(uid).set(budget.toMap(), SetOptions(merge: true));
  }

  Stream<PetProgress> watchPetProgress(String uid) {
    return _petRef(uid).snapshots().map((DocumentSnapshot<Map<String, dynamic>> doc) {
      return PetProgress.fromMap(doc.data());
    });
  }

  Future<void> savePetProgress(String uid, PetProgress petProgress) async {
    await _petRef(uid).set(petProgress.toMap(), SetOptions(merge: true));
  }
}
