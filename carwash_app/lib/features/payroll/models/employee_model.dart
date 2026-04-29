class EmployeeSalary {
  final int id;
  final double salary;
  final String paymentFrequency;
  final int workDaysPerPeriod;
  final double dailyRate;
  final DateTime effectiveFrom;

  const EmployeeSalary({
    required this.id,
    required this.salary,
    required this.paymentFrequency,
    required this.workDaysPerPeriod,
    required this.dailyRate,
    required this.effectiveFrom,
  });

  String get frequencyLabel => switch (paymentFrequency) {
    'weekly' || 'semanal' => 'Semanal',
    'biweekly' || 'quincenal' => 'Quincenal',
    'monthly' || 'mensual' => 'Mensual',
    'diario' => 'Diario',
    'otro' => 'Otro',
    _ => paymentFrequency,
  };

  factory EmployeeSalary.fromJson(Map<String, dynamic> json) => EmployeeSalary(
    id: json['id'] as int? ?? 0,
    salary: double.parse(json['salary'].toString()),
    paymentFrequency: json['payment_frequency'] as String? ?? 'semanal',
    workDaysPerPeriod: json['work_days_per_period'] as int? ?? 6,
    dailyRate: double.parse((json['daily_rate'] ?? json['salary']).toString()),
    effectiveFrom: DateTime.parse(json['effective_from'] as String),
  );
}

class Employee {
  final int id;
  final String firstName;
  final String lastName;
  final String? phone;
  final String status;
  final DateTime hireDate;
  final EmployeeSalary? currentSalary;

  const Employee({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.phone,
    required this.status,
    required this.hireDate,
    this.currentSalary,
  });

  String get fullName => '$firstName $lastName';
  bool get isActive => status == 'activo';

  factory Employee.fromJson(Map<String, dynamic> json) {
    EmployeeSalary? salary;
    final salaryMap = json['current_salary'] as Map<String, dynamic>?;
    if (salaryMap != null) {
      salary = EmployeeSalary.fromJson(salaryMap);
    } else if (json['salary'] != null) {
      salary = EmployeeSalary(
        id: 0,
        salary: double.parse(json['salary'].toString()),
        paymentFrequency: json['payment_frequency'] as String? ?? 'semanal',
        workDaysPerPeriod: json['work_days_per_period'] as int? ?? 6,
        dailyRate: double.parse(
          (json['daily_rate'] ?? json['salary']).toString(),
        ),
        effectiveFrom: json['effective_from'] != null
            ? DateTime.parse(json['effective_from'] as String)
            : DateTime.now(),
      );
    }
    final isActive = json['is_active'];
    return Employee(
      id: json['id'] as int,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      phone: json['phone'] as String?,
      status:
          json['status'] as String? ??
          (isActive is bool && !isActive ? 'inactivo' : 'activo'),
      hireDate: DateTime.parse(json['hire_date'] as String),
      currentSalary: salary,
    );
  }
}
