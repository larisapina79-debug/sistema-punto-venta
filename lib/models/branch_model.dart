
class BranchModel {
  final String id;
  final String branchName;
  final String branchAddress;
  final String branchLogo;
  final bool branchStatus;

  const BranchModel({
    required this.id,
    required this.branchName,
    required this.branchAddress,
    required this.branchLogo,
    required this.branchStatus,
  });

  factory BranchModel.fromMap(Map<String, dynamic> data) {
    return BranchModel(
      id: (data['id'] ?? '').toString(),
      branchName: (data['branch_name'] ?? '').toString(),
      branchAddress: (data['branch_address'] ?? '').toString(),
      branchLogo: (data['branch_logo'] ?? '').toString(),
      branchStatus: data['branch_status'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'branch_name': branchName,
      'branch_address': branchAddress,
      'branch_logo': branchLogo,
      'branch_status': branchStatus,
    };
  }
}
