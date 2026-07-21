import 'package:flutter/foundation.dart';

import '../db/database_helper.dart';
import '../models/goal.dart';

class GoalProvider extends ChangeNotifier {
  final _db = DatabaseHelper.instance;

  List<Goal> _goals = [];
  List<Goal> get goals => _goals;

  Future<void> load() async {
    _goals = await _db.goals();
    notifyListeners();
  }

  Future<void> addGoal(Goal goal) async {
    await _db.insertGoal(goal);
    await load();
  }

  Future<void> updateGoal(Goal goal) async {
    await _db.updateGoal(goal);
    await load();
  }
}
