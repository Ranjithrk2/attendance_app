import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/member.dart';
import 'member_report_screen.dart';
import 'add_member_screen.dart';

enum SortType {
  nameAsc,
  nameDesc,
  userId,
  role,
  recent,
}

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  bool loading = true;
  List<Member> members = [];
  List<Member> filteredMembers = [];

  final TextEditingController searchCtrl = TextEditingController();
  SortType currentSort = SortType.nameAsc;

  @override
  void initState() {
    super.initState();
    fetchMembers();
    searchCtrl.addListener(applySearchAndSort);
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  // ================= FETCH MEMBERS =================
  Future<void> fetchMembers() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('users').get();

      final list = snapshot.docs
          .map((doc) => Member.fromMap(doc.id, doc.data()))
          .toList();

      setState(() {
        members = list;
        applySearchAndSort();
        loading = false;
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() => loading = false);
    }
  }

  // ================= SEARCH + SORT =================
  void applySearchAndSort() {
    final q = searchCtrl.text.trim().toLowerCase();

    List<Member> list = members.where((m) {
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          m.userId.toLowerCase().contains(q);
    }).toList();

    list.sort((a, b) {
      switch (currentSort) {
        case SortType.nameAsc:
          return a.name.compareTo(b.name);
        case SortType.nameDesc:
          return b.name.compareTo(a.name);
        case SortType.userId:
          return a.userId.compareTo(b.userId);
        case SortType.role:
          return a.role.compareTo(b.role);
        case SortType.recent:
          return (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000));
      }
    });

    setState(() {
      filteredMembers = list;
    });
  }

  bool isHighlighted(Member m) {
    final q = searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return false;
    return m.name.toLowerCase().contains(q) ||
        m.userId.toLowerCase().contains(q);
  }

  // ================= STATUS TOGGLE =================
  Future<void> toggleStatus(Member member) async {
    final newStatus =
    member.status == 'active' ? 'suspended' : 'active';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(member.uid)
        .update({'status': newStatus});

    // 🔁 Auto checkout if suspended
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

    fetchMembers();
  }

  // ================= DELETE =================
  Future<void> deleteMember(Member member) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(member.uid)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Member deleted")),
      );

      fetchMembers();
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  void confirmDelete(Member member) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text("Delete Member",
            style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to delete this member?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel",
                style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text("Delete",
                style: TextStyle(color: Colors.redAccent)),
            onPressed: () {
              Navigator.pop(context);
              deleteMember(member);
            },
          ),
        ],
      ),
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Members"),
        actions: [
          _sortMenu(),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.cyanAccent),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AddMemberScreen()),
              );
              fetchMembers();
            },
          ),
        ],
      ),
      body: loading
          ? const Center(
        child:
        CircularProgressIndicator(color: Colors.cyanAccent),
      )
          : Column(
        children: [
          _searchBar(),
          Expanded(child: _memberList()),
        ],
      ),
    );
  }

  // ================= SORT MENU =================
  Widget _sortMenu() {
    return PopupMenuButton<SortType>(
      icon: const Icon(Icons.sort, color: Colors.cyanAccent),
      color: Colors.black,
      onSelected: (value) {
        setState(() {
          currentSort = value;
          applySearchAndSort();
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
      child: Text(text,
          style: const TextStyle(color: Colors.white)),
    );
  }

  // ================= SEARCH BAR =================
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: searchCtrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search by name or ID",
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon:
          const Icon(Icons.search, color: Colors.cyanAccent),
          filled: true,
          fillColor: Colors.white10,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ================= LIST =================
  Widget _memberList() {
    if (filteredMembers.isEmpty) {
      return const Center(
        child: Text("No members found",
            style: TextStyle(color: Colors.white54)),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredMembers.length,
      itemBuilder: (_, i) {
        final m = filteredMembers[i];
        final glow = isHighlighted(m);

        final isSuspended = m.status == 'suspended';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
              isSuspended ? Colors.redAccent : Colors.cyanAccent,
              width: 1.2,
            ),
          ),
          child: ListTile(
            title: Text(
              m.name,
              style: TextStyle(
                color: isSuspended
                    ? Colors.redAccent
                    : Colors.white,
              ),
            ),
            subtitle: Text(
              "ID: ${m.userId} • ${m.role}",
              style: const TextStyle(color: Colors.white54),
            ),
            leading: Chip(
              label: Text(
                isSuspended ? 'SUSPENDED' : 'ACTIVE',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor:
              isSuspended ? Colors.red : Colors.green,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.sync),
                  color: Colors.orangeAccent,
                  onPressed: () => toggleStatus(m),
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart,
                      color: Colors.cyanAccent),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            MemberReportScreen(member: m),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete,
                      color: Colors.redAccent),
                  onPressed: () => confirmDelete(m),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}