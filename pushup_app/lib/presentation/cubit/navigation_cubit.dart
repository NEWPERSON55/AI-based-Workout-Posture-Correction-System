import 'package:flutter_bloc/flutter_bloc.dart';

/// Manages the active tab index for the main bottom navigation.
class NavigationCubit extends Cubit<int> {
  NavigationCubit() : super(0);

  void setTab(int index) => emit(index);
}
