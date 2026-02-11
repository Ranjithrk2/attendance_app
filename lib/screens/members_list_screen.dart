import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member.dart';
import 'member_report_screen.dart';
import 'add_member_screen.dart';

enum SortType { nameAsc, nameDesc, userId, role, recent }

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  SortType currentSort = SortType.nameAsc;

  List<Member> allMembers = [];
  List<Member> displayedMembers = [];
  bool isLoading = true;

  final int pageSize = 10;
  int lastLoadedIndex = 0;
  bool hasMore = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchMembers();

    // Infinite scroll listener
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 100 &&
          !isLoading &&
          hasMore) {
        _loadMoreMembers();
      }
    });
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMembers() async {
    setState(() => isLoading = true);
    final snap = await FirebaseFirestore.instance.collection('users').get();
    final members = snap.docs
        .map((doc) => Member.fromMap(doc.id, doc.data() as Map<String, dynamic>))
        .toList();

    setState(() {
      allMembers = sortMembers(members);
      displayedMembers.clear();
      lastLoadedIndex = 0;
      hasMore = true;
      _loadMoreMembers();
    });
  }

  void _loadMoreMembers() {
    if (!hasMore) return;

    final query = searchCtrl.text.trim().toLowerCase();
    List<Member> filtered = allMembers;
    if (query.isNotEmpty) {
      filtered = allMembers
          .where((m) =>
      m.name.toLowerCase().contains(query) ||
          m.userId.toLowerCase().contains(query))
          .toList();
    }

    final nextIndex = lastLoadedIndex + pageSize;
    if (lastLoadedIndex >= filtered.length) {
      hasMore = false;
      return;
    }

    setState(() {
      displayedMembers.addAll(
          filtered.sublist(lastLoadedIndex, nextIndex > filtered.length ? filtered.length : nextIndex));
      lastLoadedIndex = nextIndex;
      if (lastLoadedIndex >= filtered.length) hasMore = false;
      isLoading = false;
    });
  }

  Future<void> toggleStatus(Member member) async {
    final newStatus = member.status == 'active' ? 'suspended' : 'active';
    await FirebaseFirestore.instance
        .collection('users')
        .doc(member.uid)
        .update({'status': newStatus});

    if (newStatus == 'suspended') {
      final snap = await FirebaseFirestore.instance
          .collection('attendance')
          .where('userId', isEqualTo: member.uid)
          .where('checkOut', isNull: true)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({
          'checkOut': Timestamp.now(),
          'autoCheckedOut': true,
        });
      }
    }

    await _fetchMembers();
  }

  Future<void> deleteMember(Member member) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(member.uid).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Member deleted")),
      );
      await _fetchMembers();
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  void confirmDelete(Member member) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Delete Member", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to delete this member?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              Navigator.pop(context);
              deleteMember(member);
            },
          ),
        ],
      ),
    );
  }

  List<Member> sortMembers(List<Member> list) {
    switch (currentSort) {
      case SortType.nameAsc:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case SortType.nameDesc:
        list.sort((a, b) => b.name.compareTo(a.name));
        break;
      case SortType.userId:
        list.sort((a, b) => a.userId.compareTo(b.userId));
        break;
      case SortType.role:
        list.sort((a, b) => a.role.compareTo(b.role));
        break;
      case SortType.recent:
        list.sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
        break;
    }
    return list;
  }

  void _onSearchChanged() {
    displayedMembers.clear();
    lastLoadedIndex = 0;
    hasMore = true;
    _loadMoreMembers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text("Members"),
        actions: [
          _sortMenu(),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.cyanAccent),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMemberScreen()),
              );
              await _fetchMembers();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _searchBar(),
          Expanded(
            child: displayedMembers.isEmpty && !isLoading
                ? const Center(
              child: Text("No members found",
                  style: TextStyle(color: Colors.white54)),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: displayedMembers.length + 1,
              itemBuilder: (_, i) {
                if (i == displayedMembers.length) {
                  // Loader at the bottom
                  return hasMore
                      ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.cyanAccent),
                    ),
                  )
                      : const SizedBox.shrink();
                }

                final m = displayedMembers[i];
                final isSuspended = m.status == 'suspended';
                return Card(
                  color: Colors.grey[850],
                  shadowColor: Colors.black54,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSuspended ? Colors.redAccent : Colors.cyanAccent,
                      width: 1,
                    ),
                  ),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSuspended ? Colors.red : Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isSuspended ? 'SUSPENDED' : 'ACTIVE',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      m.name,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight:
                          isSuspended ? FontWeight.w500 : FontWeight.w600),
                    ),
                    subtitle: Text(
                      "ID: ${m.userId} • ${m.role}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.cyanAccent),
                      color: Colors.grey[850],
                      onSelected: (value) {
                        switch (value) {
                          case 'toggleStatus':
                            toggleStatus(m);
                            break;
                          case 'viewReport':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => MemberReportScreen(member: m)),
                            );
                            break;
                          case 'delete':
                            confirmDelete(m);
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'toggleStatus',
                          child: Text(
                            isSuspended ? 'Activate' : 'Suspend',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'viewReport',
                          child:
                          Text('View Report', style: TextStyle(color: Colors.white)),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ================= SORT MENU =================
  Widget _sortMenu() {
    return PopupMenuButton<SortType>(
      icon: const Icon(Icons.sort, color: Colors.cyanAccent),
      color: Colors.grey[850],
      onSelected: (value) {
        setState(() {
          currentSort = value;
          allMembers = sortMembers(allMembers);
          displayedMembers.clear();
          lastLoadedIndex = 0;
          hasMore = true;
          _loadMoreMembers();
        });
      },
      itemBuilder: (_) => [
        _menuItem("Name (A–Z)", SortType.nameAsc),
        _menuItem("Name (Z–A)", SortType.nameDesc),
        _menuItem("User ID", SortType.userId),
        _menuItem("Role", SortType.role),
        _menuItem("Recently Added", SortType.recent),
      ],
    );
  }

  PopupMenuItem<SortType> _menuItem(String text, SortType value) {
    return PopupMenuItem(
      value: value,
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }

  // ================= SEARCH BAR =================
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: searchCtrl,
        onChanged: (_) => _onSearchChanged(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search by name or ID",
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}