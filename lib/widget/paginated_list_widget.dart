import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Widget réutilisable pour les listes paginées Firestore
/// 
/// Utilisation:
/// ```dart
/// PaginatedListWidget<DocumentSnapshot>(
///   query: appFirestore
///       .collection('users')
///       .orderBy('lastName')
///       .limit(20),
///   itemBuilder: (context, doc, index) => ListTile(
///     title: Text(doc.data()['name']),
///   ),
///   emptyWidget: Center(child: Text('Aucun résultat')),
/// )
/// ```
class PaginatedListWidget<T extends DocumentSnapshot> extends StatefulWidget {
  final Query<T> query;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Widget? emptyWidget;
  final int pageSize;
  final Widget? loadingWidget;

  const PaginatedListWidget({
    super.key,
    required this.query,
    required this.itemBuilder,
    this.emptyWidget,
    this.pageSize = 20,
    this.loadingWidget,
  });

  @override
  State<PaginatedListWidget<T>> createState() => _PaginatedListWidgetState<T>();
}

class _PaginatedListWidgetState<T extends DocumentSnapshot>
    extends State<PaginatedListWidget<T>> {
  final List<T> _items = [];
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = widget.query.limit(widget.pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
          _isInitialLoad = false;
        });
      } else {
        setState(() {
          _items.addAll(snapshot.docs as List<T>);
          _lastDocument = snapshot.docs.last;
          _hasMore = snapshot.docs.length == widget.pageSize;
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isInitialLoad = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoad) {
      return widget.loadingWidget ?? 
          const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty && !_hasMore) {
      return widget.emptyWidget ?? 
          const Center(child: Text('Aucun résultat'));
    }

    return ListView.builder(
      itemCount: _items.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          // Dernier item = loader pour charger plus
          _loadMore();
          return widget.loadingWidget ?? 
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
        }
        return widget.itemBuilder(context, _items[index], index);
      },
    );
  }
}
