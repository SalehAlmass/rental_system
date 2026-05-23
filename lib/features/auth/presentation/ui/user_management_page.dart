import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rental_app/core/widgets/custom_app_bar.dart';
import '../bloc/user_management_bloc.dart';
import '../../domain/entities/user_model.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  @override
  void initState() {
    super.initState();
    context.read<UserManagementBloc>().add(LoadUsers());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserManagementBloc, UserManagementState>(
      listener: (context, state) {
        if (state is UserManagementError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is UserManagementPasswordChanged) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: CustomAppBar(
            title: 'إدارة المستخدمين',
            onIconPressed: widget.showBackButton ? (){
              Navigator.of(context).pop();
            } : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.manage_accounts_outlined , 
                  color: Colors.white, size: 28),
                onPressed: () => _showCreateUserDialog(context),
              ),
            ],
          ),
          floatingActionButton: _buildFAB(),
          body: _buildBody(state),
        );
      },
    );
  }

  Widget _buildBody(UserManagementState state) {
    if (state is UserManagementLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is UserManagementLoaded) {
      if (state.users.isEmpty) {
        return const Center(child: Text('لا يوجد مستخدمين'));
      }

      return RefreshIndicator(
        onRefresh: () async {
          context.read<UserManagementBloc>().add(LoadUsers());
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: state.users.length,
          itemBuilder: (context, index) => _buildUserCard(state.users[index]),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // =================== User Card ===================
  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      shadowColor: Colors.grey.shade300,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: _getRoleColor(user.role),
          child: const Icon(Icons.person, color: Colors.white, size: 28),
        ),
        title: Text(
          user.username,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          '${_getRoleDisplay(user.role)} • ${user.isActive ? "نشط" : "غير نشط"}'
          'حساب الساعات: ${_modeLabel(user.contractHourPricingMode)} • سند القبض: ${_modeLabel(user.contractPaymentReceiptMode)}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            if (value == 'edit') {
              _showEditUserDialog(context, user);
            } else if (value == 'delete') _showDeleteDialog(context, user);
            else if (value == 'toggle') {
              context.read<UserManagementBloc>().add(
                    UpdateUser(id: user.id, isActive: !user.isActive),
                  );
            } else if (value == 'change_password') {
              _showChangePasswordDialog(context, user);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            const PopupMenuItem(value: 'delete', child: Text('حذف')),
            PopupMenuItem(
              value: 'toggle',
              child: Text(user.isActive ? 'تعطيل المستخدم' : 'تفعيل المستخدم'),
            ),
            const PopupMenuItem(value: 'change_password', child: Text('تغيير كلمة المرور')),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.redAccent.shade400;
      case 'manager':
        return Colors.orangeAccent.shade400;
      default:
        return Colors.blueAccent.shade400;
    }
  }

  String _getRoleDisplay(String role) {
    switch (role) {
      case 'admin':
        return 'مدير';
      case 'manager':
        return 'مشرف';
      default:
        return 'موظف';
    }
  }


  String _modeLabel(String mode) {
    switch (mode) {
      case 'auto':
        return 'تلقائي';
      case 'ask':
        return 'إشعار اختياري';
      default:
        return 'حسب الإعداد العام';
    }
  }

  Map<String, dynamic> _buildPermissions({required String hourMode, required String receiptMode}) {
    return {
      'contract_hour_pricing_mode': hourMode,
      'contract_payment_receipt_mode': receiptMode,
    };
  }

  Widget _permissionSection({
    required StateSetter setModalState,
    required String hourMode,
    required String receiptMode,
    required ValueChanged<String> onHourChanged,
    required ValueChanged<String> onReceiptChanged,
    bool allowInherit = true,
  }) {
    final items = <DropdownMenuItem<String>>[
      if (allowInherit) const DropdownMenuItem(value: 'inherit', child: Text('حسب الإعداد العام')),
      const DropdownMenuItem(value: 'auto', child: Text('تلقائي')),
      const DropdownMenuItem(value: 'ask', child: Text('إشعار اختياري')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        const Text('صلاحيات إغلاق العقود', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: hourMode,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'احتساب الساعات عند الإغلاق',
          ),
          items: items,
          onChanged: (v) => setModalState(() => onHourChanged(v ?? (allowInherit ? 'inherit' : 'ask'))),
        ),
        const SizedBox(height: 8),
        Text('الوضع الحالي: ${_modeLabel(hourMode)}', style: TextStyle(color: Colors.grey.shade700)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: receiptMode,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'سند القبض عند إغلاق العقد',
          ),
          items: items,
          onChanged: (v) => setModalState(() => onReceiptChanged(v ?? (allowInherit ? 'inherit' : 'auto'))),
        ),
        const SizedBox(height: 8),
        Text('الوضع الحالي: ${_modeLabel(receiptMode)}', style: TextStyle(color: Colors.grey.shade700)),
      ],
    );
  }

  // =================== Dialogs ===================
  void _showChangePasswordDialog(BuildContext context, User user) {
    final newPassword = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: newPassword,
          decoration: InputDecoration(
            labelText: 'كلمة المرور الجديدة',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          obscureText: true,
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              elevation: 3,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final password = newPassword.text.trim();
              if (password.isNotEmpty) {
                context.read<UserManagementBloc>().add(
                      ChangeUserPassword(id: user.id, newPassword: password),
                    );
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('يرجى إدخال كلمة مرور جديدة')),
                );
              }
            },
            child: const Text('تحديث', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }


  void _showCreateUserDialog(BuildContext context) {
    final username = TextEditingController();
    final password = TextEditingController();
    String role = 'employee';
    String hourMode = 'inherit';
    String receiptMode = 'inherit';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('إضافة مستخدم', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'اسم المستخدم'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: password,
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField(
                  initialValue: role,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'الدور'),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('موظف')),
                    DropdownMenuItem(value: 'manager', child: Text('مشرف')),
                    DropdownMenuItem(value: 'admin', child: Text('مدير')),
                  ],
                  onChanged: (v) => setModalState(() => role = v.toString()),
                ),
                _permissionSection(
                  setModalState: setModalState,
                  hourMode: hourMode,
                  receiptMode: receiptMode,
                  onHourChanged: (v) => hourMode = v,
                  onReceiptChanged: (v) => receiptMode = v,
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 3,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                context.read<UserManagementBloc>().add(
                      CreateUser(
                        username: username.text.trim(),
                        password: password.text,
                        role: role,
                        permissions: _buildPermissions(hourMode: hourMode, receiptMode: receiptMode),
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('إنشاء', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }


  void _showEditUserDialog(BuildContext context, User user) {
    final username = TextEditingController(text: user.username);
    bool isActive = user.isActive;
    String role = user.role;
    String hourMode = user.contractHourPricingMode;
    String receiptMode = user.contractPaymentReceiptMode;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('تعديل المستخدم', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: username, decoration: const InputDecoration(labelText: 'اسم المستخدم')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'الدور'),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('موظف')),
                    DropdownMenuItem(value: 'manager', child: Text('مشرف')),
                    DropdownMenuItem(value: 'admin', child: Text('مدير')),
                  ],
                  onChanged: (v) => setModalState(() => role = v ?? user.role),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('المستخدم نشط'),
                  value: isActive,
                  onChanged: (val) => setModalState(() => isActive = val),
                ),
                _permissionSection(
                  setModalState: setModalState,
                  hourMode: hourMode,
                  receiptMode: receiptMode,
                  onHourChanged: (v) => hourMode = v,
                  onReceiptChanged: (v) => receiptMode = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                elevation: 3,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                context.read<UserManagementBloc>().add(
                      UpdateUser(
                        id: user.id,
                        username: username.text,
                        role: role,
                        isActive: isActive,
                        permissions: _buildPermissions(hourMode: hourMode, receiptMode: receiptMode),
                      ),
                    );
                Navigator.pop(context);
              },
              child: const Text('تحديث', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تأكيد الحذف', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('هل تريد حذف ${user.username} ؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              context.read<UserManagementBloc>().add(DeleteUser(id: user.id));
              Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // =================== FAB ===================
  FloatingActionButton _buildFAB() {
    return FloatingActionButton.extended(
      heroTag: 'add_user',
      icon: const Icon(Icons.person_add),
      label: const Text('إضافة مستخدم'),
      backgroundColor: Colors.blueAccent,
      elevation: 6,
      onPressed: () => _showCreateUserDialog(context),
    );
  }
}
