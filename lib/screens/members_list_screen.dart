import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member.dart';
import 'member_report_screen.dart';
import 'add_member_screen.dart';

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

  @override
  void initState() {
    super.initState();
    fetchMembers();
    searchCtrl.addListener(filterMembers);
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
        filteredMembers = list;
        loading = false;
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
      setState(() => loading = false);
    }
  }

  // ================= SEARCH + GLOW =================
  void filterMembers() {
    final q = searchCtrl.text.trim().toLowerCase();

    if (q.isEmpty) {
      setState(() => filteredMembers = members);
      return;
    }

    final matches = members.where((m) {
      return m.name.toLowerCase().contains(q) ||
          m.userId.toLowerCase().contains(q);
    }).toList();

    setState(() {
      filteredMembers = matches;
    });
  }

  bool isHighlighted(Member m) {
    final q = searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return false;
    return m.name.toLowerCase().contains(q) ||
        m.userId.toLowerCase().contains(q);
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
            child:
            const Text("Cancel", style: TextStyle(color: Colors.white54)),
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
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.cyanAccent),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMemberScreen()),
              );
              fetchMembers(); // refresh after add
            },
          ),
        ],
      ),

      body: loading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      )
          : Column(
        children: [
          // ================= SEARCH BAR =================
          Padding(
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
          ),

          // ================= LIST =================
          Expanded(
            child: filteredMembers.isEmpty
                ? const Center(
              child: Text("No members found",
                  style: TextStyle(color: Colors.white54)),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredMembers.length,
              itemBuilder: (_, i) {
                final m = filteredMembers[i];
                final glow = isHighlighted(m);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: glow
                        ? [
                      BoxShadow(
                        color: Colors.cyanAccent
                            .withOpacity(0.6),
                        blurRadius: 16,
                        spreadRadius: 1,
                      )
                    ]
                        : [],
                    border: glow
                        ? Border.all(
                        color: Colors.cyanAccent, width: 1.5)
                        : null,
                  ),
                  child: ListTile(
                    title: Text(
                      m.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      "ID: ${m.userId} • ${m.role}",
                      style: TextStyle(
                        color: glow
                            ? Colors.cyanAccent
                            : Colors.white54,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
            ),
          ),
        ],
      ),
    );
  }
}
