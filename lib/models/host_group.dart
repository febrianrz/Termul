class HostGroup {
  final String id;
  String name;

  HostGroup({required this.id, required this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  factory HostGroup.fromMap(Map<dynamic, dynamic> map) => HostGroup(
    id: map['id'] as String,
    name: map['name'] as String,
  );
}
