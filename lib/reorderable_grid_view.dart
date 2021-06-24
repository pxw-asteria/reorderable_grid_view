import 'package:flutter/material.dart';

/// Usage:
/// ```
/// ReorderableGridView(
///   crossAxisCount: 3,
///   children: this.data.map((e) => buildItem("$e")).toList(),
///   onReorder: (oldIndex, newIndex) {
///     setState(() {
///       final element = data.removeAt(oldIndex);
///       data.insert(newIndex, element);
///     });
///   },
/// )
///```
class ReorderableGridView extends StatefulWidget {
  final List<Widget> children;
  final List<Widget> footer;
  final int crossAxisCount;
  final ReorderCallback onReorder;
  final bool primary;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final bool shrinkWrap;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics physics;
  final bool reverse;
  final double cacheExtent;
  final int semanticChildCount;
  final bool addAutomaticKeepAlives;
  final bool addRepaintBoundaries;
  final addSemanticIndexes;

  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final Clip clipBehavior;
  final String restorationId;

  /// The ratio of the cross-axis to the main-axis extent of each child.
  final double childAspectRatio;

  /// I think anti multi drag is loss performance.
  /// So default is false, and only set if you care this case.
  final bool antiMultiDrag;

  ReorderableGridView(
    {
      Key key,
      this.children,
      this.clipBehavior = Clip.hardEdge,
      this.cacheExtent,
      this.semanticChildCount,
      this.keyboardDismissBehavior  = ScrollViewKeyboardDismissBehavior.manual,
      this.restorationId,
      this.reverse = false,
      this.crossAxisCount,
      this.padding,
      this.onReorder,
      this.physics,
      this.footer,
      this.primary,
      this.mainAxisSpacing = 0.0,
      this.crossAxisSpacing = 0.0,
      this.childAspectRatio = 1.0,
      this.addAutomaticKeepAlives = true,
      this.addRepaintBoundaries = true,
      this.addSemanticIndexes = true,
      this.shrinkWrap = true,
      this.antiMultiDrag = false,
    })
    : assert(children != null),
      assert(crossAxisCount != null),
      assert(onReorder != null),
      super(key: key);

  @override
  _ReorderableGridViewState createState() => _ReorderableGridViewState();
}

class _ReorderableGridViewState extends State<ReorderableGridView>
    with TickerProviderStateMixin<ReorderableGridView> {
  List<GridItemWrapper> _items = [];

  // The widget to move the dragging widget too after the current index.
  int _nextIndex = 0;

  // The location that the dragging widget occupied before it started to drag.
  int _dragStartIndex = 0;

  // occupies 占用
  // The index that the dragging widget currently occupies.
  int _currentIndex = 0;

  int _touchingIndex = -1;

  // 好像不能共用controller
  // This controls the entrance of the dragging widget into a new place.
  AnimationController _entranceController;

  // How long an animation to reorder an element in the list takes.
  static const Duration _reorderAnimationDuration = Duration(milliseconds: 200);

  // The member of widget.children currently being dragged.
  //
  // Null if no drag is underway.
  Key _dragging;

  double width;
  double height;

  _initItems() {
    _items.clear();
    for (var i = 0; i < widget.children.length; i++) {
      _items.add(GridItemWrapper(index: i));
    }
  }

  @override
  void initState() {
    super.initState();
    _debug("initState, child count: ${this.widget.children?.length ?? -1}");
    _entranceController =
        AnimationController(vsync: this, duration: _reorderAnimationDuration);
    _entranceController.addStatusListener(_onEntranceStatusChanged);

    _initItems();
  }

  @override
  void didUpdateWidget(covariant ReorderableGridView oldWidget) {
    _initItems();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  // Places the value from startIndex one space before the element at endIndex.
  void reorder(int startIndex, int endIndex) {
    // what to do??
    setState(() {
      if (startIndex != endIndex) widget.onReorder(startIndex, endIndex);
      // Animates leftover space in the drop area closed.
      _entranceController.reverse(from: 0);
      _initItems();
      _dragging = null;
    });
  }

  // Drops toWrap into the last position it was hovering over.
  void onDragEnded() {
    reorder(_dragStartIndex, _currentIndex);
  }

  // Animates the droppable space from _currentIndex to _nextIndex.
  void _requestAnimationToNextIndex() {
    _debug(
        "_requestAnimationToNextIndex, state: ${_entranceController.status}");
    if (_entranceController.isCompleted) {
      if (_nextIndex == _currentIndex) {
        return;
      }

      var temp = new List<int>.generate(_items.length, (index) => index);

      // 怎么处理连续滑动？？
      var old = temp.removeAt(_dragStartIndex);
      temp.insert(_nextIndex, old);

      for (var i = 0; i < _items.length; i++) {
        _items[i].nextIndex = temp.indexOf(i);
      }
      _debug("items: ${_items.map((e) => e.toString()).join(",")}");

      _currentIndex = _nextIndex;
      _entranceController.forward(from: 0.0);
    }
  }

  // Requests animation to the latest next index if it changes during an animation.
  void _onEntranceStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _items.forEach((element) {
        element.animFinish();
      });
      setState(() {
        _requestAnimationToNextIndex();
      });
    }
  }

  Widget _wrap(Widget toWrap, int index) {
    assert(toWrap.key != null);

    _debug("_wrap called for index: $index");
    var canDrag = true;
    if (widget.antiMultiDrag) {
      var isDragging = _dragging != null;
      canDrag = (_touchingIndex == -1 || _touchingIndex == index) && !isDragging;
    }
    Widget buildDragTarget(BuildContext context, List<Key> acceptedCandidates,
        List<dynamic> rejectedCandidates, BoxConstraints constraints) {
      var itemWidth = constraints.maxWidth;
      var itemHeight = constraints.maxHeight;

      // you can't access other's state, so why your _maxDragCount work?
      // I think I need a preCheck to let longPressDraggable to begin drag.
      Widget child = LongPressDraggable<Key>(
        data: toWrap.key,
        maxSimultaneousDrags: canDrag? 1: 0,
        // feed back is the view follow pointer
        feedback: Container(
          // actually, this constraints is not necessary here.
          // but how to calculate the toWrap size and give feedback.
          constraints: constraints,
          child: Material(elevation: 3.0, child: toWrap),
        ),
        child: _dragging == toWrap.key ? SizedBox() : toWrap,
        childWhenDragging: const SizedBox(),
        onDragStarted: () {
          // _isDragging = true;
          _dragStartIndex = index;
          _currentIndex = index;

          // this is will set _entranceController to complete state.
          // ok ready to start animation
          _entranceController.value = 1.0;
          _dragging = toWrap.key;
        },
        onDragCompleted: onDragEnded,
        onDraggableCanceled: (Velocity velocity, Offset offset) {
          onDragEnded();
        },
      );

      // _debug('the item size: ${constraints.minWidth}-${constraints.maxWidth}');
      var item = _items[index];

      // any better way to do this?
      var fromPos = item.getBeginOffset(this.widget.crossAxisCount);
      var toPos = item.getEndOffset(this.widget.crossAxisCount);

      var begin = item.adjustOffset(fromPos, itemWidth, itemHeight, widget.mainAxisSpacing, widget.crossAxisSpacing);
      var end = item.adjustOffset(toPos, itemWidth, itemHeight, widget.mainAxisSpacing, widget.crossAxisSpacing);


      // it's worse performance
      // if (fromPos != toPos) {
      //   return SlideTransition(
      //     position:
      //     Tween<Offset>(begin: begin, end: end)
      //         .animate(_entranceController),
      //     child: child,
      //   );
      // } else if (item.hasMoved()) {
      //   return SlideTransition(
      //     position:
      //     Tween<Offset>(begin: end, end: end)
      //         .animate(_entranceController),
      //     child: child,
      //   );
      // } else {
      //   return child;
      // }


      // Better same struct??
      // How entranceController work? If it's actioning, I setState, how it will eb?
      if (fromPos != toPos) {
        return SlideTransition(
          position:
          Tween<Offset>(begin: begin, end: end)
              .animate(_entranceController),
          child: child,
        );
      } else if (item.hasMoved()) {
        // Is Transform better performance than SlideTransition, maybe.
        return Transform.translate(
          offset: Offset(end.dx * itemWidth, end.dy * itemHeight),
          child: child,
        );
      } else {
        return child;
      }

    }

    // If I want in a Gesture?
    return LayoutBuilder(
      builder: (context, constraints) {
        // I think it's strange that I can get the right constraints at here.
        var content = DragTarget<Key>(
          builder: (context, acceptedCandidates, rejectedCandidates) =>
              buildDragTarget(
                  context, acceptedCandidates, rejectedCandidates, constraints),
          onWillAccept: (Key toAccept) {
            _debug("onWillAccept called for index: $index");
            // how can we change the state?
            setState(() {
              _nextIndex = index;
              _requestAnimationToNextIndex();
            });

            // now let's try scroll.
            return _dragging == toAccept && toAccept != toWrap.key;
          },
        );

        if (widget.antiMultiDrag) {
          return GestureDetector(
            onTapDown: (e) {
              setState(() {
                _touchingIndex = index;
              });
            },
            onTapUp: (e) {
              setState(() {
                _debug("onTapUp");
                _touchingIndex = -1;
              });
            },
            onTapCancel: () {
              setState(() {
                // If drag start, onTapCancel will trigger.
                _debug("onTapCancel");
                _touchingIndex = -1;
              });
            },
            child: content,
          );
        } else {
          return content;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      children.add(_wrap(widget.children[i], i));
    }
    children.addAll(widget?.footer?? []);

    return LayoutBuilder(
      builder: (context, constraints) {
        width = constraints.maxWidth;
        height = width * widget.childAspectRatio;
        return GridView.count(
          children: children,
          reverse: widget.reverse,
          primary: widget.primary,
          physics: widget.physics,
          cacheExtent: widget.cacheExtent,
          semanticChildCount: widget.semanticChildCount,
          restorationId: widget.restorationId,
          clipBehavior: widget.clipBehavior,
          crossAxisCount: widget.crossAxisCount,
          mainAxisSpacing: widget.mainAxisSpacing,
          crossAxisSpacing: widget.crossAxisSpacing,
          childAspectRatio: widget.childAspectRatio,
          addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
          addRepaintBoundaries: widget.addRepaintBoundaries,
          addSemanticIndexes: widget.addSemanticIndexes,
          shrinkWrap: widget.shrinkWrap,
          padding: widget.padding,

        );
      },
    );
  }
}

class GridItemWrapper {
  int index;
  int curIndex;
  int nextIndex;

  GridItemWrapper({this.index}) : assert(index != null) {
    curIndex = index;
    nextIndex = index;
  }

  // What's better offset with
  Offset adjustOffset(_Pos pos, double width, double height, double mainSpace,
      double crossSpace) {
    return Offset(pos.col.toDouble() + pos.col * mainSpace / width,
        pos.row + pos.row * crossSpace / height);
  }

  _Pos getBeginOffset(int crossAxisCount) {
    var origin = _getPos(index, crossAxisCount);
    var pos = _getPos(curIndex, crossAxisCount);
    return _Pos(col: (pos.col - origin.col), row: (pos.row - origin.row));
  }

  _Pos getEndOffset(int crossAxisCount) {
    var origin = _getPos(index, crossAxisCount);
    var pos = _getPos(nextIndex, crossAxisCount);
    return _Pos(col: (pos.col - origin.col), row: (pos.row - origin.row));
  }

  void animFinish() {
    curIndex = nextIndex;
  }

  bool hasMoved() {
    return index != curIndex;
  }

  @override
  String toString() {
    return 'GridItemWrapper{index: $index, curIndex: $curIndex, nextIndex: $nextIndex}';
  }
}

class _Pos {
  int row;
  int col;

  _Pos({this.row, this.col})
      : assert(row != null),
        assert(col != null);

  _Pos operator -(_Pos other) =>
      _Pos(row: row - other.row, col: col - other.col);

  _Pos operator +(_Pos other) =>
      _Pos(row: row + other.row, col: col + other.col);

  Offset toOffset() {
    return Offset(col.toDouble(), row.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _Pos &&
          runtimeType == other.runtimeType &&
          row == other.row &&
          col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

const _IS_DEBUG = false;

_debug(String msg) {
  if (_IS_DEBUG) {
    print("ReorderableGridView: " + msg);
  }
}

_Pos _getPos(int index, int crossAxisCount) {
  return _Pos(row: index ~/ crossAxisCount, col: index % crossAxisCount);
}

