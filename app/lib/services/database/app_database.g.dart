// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MealsTable extends Meals with TableInfo<$MealsTable, Meal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealTypeMeta = const VerificationMeta(
    'mealType',
  );
  @override
  late final GeneratedColumn<String> mealType = GeneratedColumn<String>(
    'meal_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _overallSymptomsMeta = const VerificationMeta(
    'overallSymptoms',
  );
  @override
  late final GeneratedColumn<String> overallSymptoms = GeneratedColumn<String>(
    'overall_symptoms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawInputMeta = const VerificationMeta(
    'rawInput',
  );
  @override
  late final GeneratedColumn<String> rawInput = GeneratedColumn<String>(
    'raw_input',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageDataMeta = const VerificationMeta(
    'imageData',
  );
  @override
  late final GeneratedColumn<Uint8List> imageData = GeneratedColumn<Uint8List>(
    'image_data',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    time,
    mealType,
    overallSymptoms,
    rawInput,
    createdAt,
    imageData,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('meal_type')) {
      context.handle(
        _mealTypeMeta,
        mealType.isAcceptableOrUnknown(data['meal_type']!, _mealTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_mealTypeMeta);
    }
    if (data.containsKey('overall_symptoms')) {
      context.handle(
        _overallSymptomsMeta,
        overallSymptoms.isAcceptableOrUnknown(
          data['overall_symptoms']!,
          _overallSymptomsMeta,
        ),
      );
    }
    if (data.containsKey('raw_input')) {
      context.handle(
        _rawInputMeta,
        rawInput.isAcceptableOrUnknown(data['raw_input']!, _rawInputMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('image_data')) {
      context.handle(
        _imageDataMeta,
        imageData.isAcceptableOrUnknown(data['image_data']!, _imageDataMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      )!,
      mealType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_type'],
      )!,
      overallSymptoms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}overall_symptoms'],
      ),
      rawInput: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_input'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      imageData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}image_data'],
      ),
    );
  }

  @override
  $MealsTable createAlias(String alias) {
    return $MealsTable(attachedDatabase, alias);
  }
}

class Meal extends DataClass implements Insertable<Meal> {
  final int id;
  final DateTime date;
  final String time;
  final String mealType;
  final String? overallSymptoms;
  final String? rawInput;
  final DateTime createdAt;
  final Uint8List? imageData;
  const Meal({
    required this.id,
    required this.date,
    required this.time,
    required this.mealType,
    this.overallSymptoms,
    this.rawInput,
    required this.createdAt,
    this.imageData,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['time'] = Variable<String>(time);
    map['meal_type'] = Variable<String>(mealType);
    if (!nullToAbsent || overallSymptoms != null) {
      map['overall_symptoms'] = Variable<String>(overallSymptoms);
    }
    if (!nullToAbsent || rawInput != null) {
      map['raw_input'] = Variable<String>(rawInput);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || imageData != null) {
      map['image_data'] = Variable<Uint8List>(imageData);
    }
    return map;
  }

  MealsCompanion toCompanion(bool nullToAbsent) {
    return MealsCompanion(
      id: Value(id),
      date: Value(date),
      time: Value(time),
      mealType: Value(mealType),
      overallSymptoms: overallSymptoms == null && nullToAbsent
          ? const Value.absent()
          : Value(overallSymptoms),
      rawInput: rawInput == null && nullToAbsent
          ? const Value.absent()
          : Value(rawInput),
      createdAt: Value(createdAt),
      imageData: imageData == null && nullToAbsent
          ? const Value.absent()
          : Value(imageData),
    );
  }

  factory Meal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meal(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      time: serializer.fromJson<String>(json['time']),
      mealType: serializer.fromJson<String>(json['mealType']),
      overallSymptoms: serializer.fromJson<String?>(json['overallSymptoms']),
      rawInput: serializer.fromJson<String?>(json['rawInput']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      imageData: serializer.fromJson<Uint8List?>(json['imageData']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'time': serializer.toJson<String>(time),
      'mealType': serializer.toJson<String>(mealType),
      'overallSymptoms': serializer.toJson<String?>(overallSymptoms),
      'rawInput': serializer.toJson<String?>(rawInput),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'imageData': serializer.toJson<Uint8List?>(imageData),
    };
  }

  Meal copyWith({
    int? id,
    DateTime? date,
    String? time,
    String? mealType,
    Value<String?> overallSymptoms = const Value.absent(),
    Value<String?> rawInput = const Value.absent(),
    DateTime? createdAt,
    Value<Uint8List?> imageData = const Value.absent(),
  }) => Meal(
    id: id ?? this.id,
    date: date ?? this.date,
    time: time ?? this.time,
    mealType: mealType ?? this.mealType,
    overallSymptoms: overallSymptoms.present
        ? overallSymptoms.value
        : this.overallSymptoms,
    rawInput: rawInput.present ? rawInput.value : this.rawInput,
    createdAt: createdAt ?? this.createdAt,
    imageData: imageData.present ? imageData.value : this.imageData,
  );
  Meal copyWithCompanion(MealsCompanion data) {
    return Meal(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      time: data.time.present ? data.time.value : this.time,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      overallSymptoms: data.overallSymptoms.present
          ? data.overallSymptoms.value
          : this.overallSymptoms,
      rawInput: data.rawInput.present ? data.rawInput.value : this.rawInput,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      imageData: data.imageData.present ? data.imageData.value : this.imageData,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meal(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('mealType: $mealType, ')
          ..write('overallSymptoms: $overallSymptoms, ')
          ..write('rawInput: $rawInput, ')
          ..write('createdAt: $createdAt, ')
          ..write('imageData: $imageData')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    time,
    mealType,
    overallSymptoms,
    rawInput,
    createdAt,
    $driftBlobEquality.hash(imageData),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meal &&
          other.id == this.id &&
          other.date == this.date &&
          other.time == this.time &&
          other.mealType == this.mealType &&
          other.overallSymptoms == this.overallSymptoms &&
          other.rawInput == this.rawInput &&
          other.createdAt == this.createdAt &&
          $driftBlobEquality.equals(other.imageData, this.imageData));
}

class MealsCompanion extends UpdateCompanion<Meal> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> time;
  final Value<String> mealType;
  final Value<String?> overallSymptoms;
  final Value<String?> rawInput;
  final Value<DateTime> createdAt;
  final Value<Uint8List?> imageData;
  const MealsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.time = const Value.absent(),
    this.mealType = const Value.absent(),
    this.overallSymptoms = const Value.absent(),
    this.rawInput = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.imageData = const Value.absent(),
  });
  MealsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String time,
    required String mealType,
    this.overallSymptoms = const Value.absent(),
    this.rawInput = const Value.absent(),
    required DateTime createdAt,
    this.imageData = const Value.absent(),
  }) : date = Value(date),
       time = Value(time),
       mealType = Value(mealType),
       createdAt = Value(createdAt);
  static Insertable<Meal> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? time,
    Expression<String>? mealType,
    Expression<String>? overallSymptoms,
    Expression<String>? rawInput,
    Expression<DateTime>? createdAt,
    Expression<Uint8List>? imageData,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (time != null) 'time': time,
      if (mealType != null) 'meal_type': mealType,
      if (overallSymptoms != null) 'overall_symptoms': overallSymptoms,
      if (rawInput != null) 'raw_input': rawInput,
      if (createdAt != null) 'created_at': createdAt,
      if (imageData != null) 'image_data': imageData,
    });
  }

  MealsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? time,
    Value<String>? mealType,
    Value<String?>? overallSymptoms,
    Value<String?>? rawInput,
    Value<DateTime>? createdAt,
    Value<Uint8List?>? imageData,
  }) {
    return MealsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      mealType: mealType ?? this.mealType,
      overallSymptoms: overallSymptoms ?? this.overallSymptoms,
      rawInput: rawInput ?? this.rawInput,
      createdAt: createdAt ?? this.createdAt,
      imageData: imageData ?? this.imageData,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(mealType.value);
    }
    if (overallSymptoms.present) {
      map['overall_symptoms'] = Variable<String>(overallSymptoms.value);
    }
    if (rawInput.present) {
      map['raw_input'] = Variable<String>(rawInput.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (imageData.present) {
      map['image_data'] = Variable<Uint8List>(imageData.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('mealType: $mealType, ')
          ..write('overallSymptoms: $overallSymptoms, ')
          ..write('rawInput: $rawInput, ')
          ..write('createdAt: $createdAt, ')
          ..write('imageData: $imageData')
          ..write(')'))
        .toString();
  }
}

class $FoodItemsTable extends FoodItems
    with TableInfo<$FoodItemsTable, FoodItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<int> mealId = GeneratedColumn<int>(
    'meal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meals (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _portionMeta = const VerificationMeta(
    'portion',
  );
  @override
  late final GeneratedColumn<String> portion = GeneratedColumn<String>(
    'portion',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _prepMeta = const VerificationMeta('prep');
  @override
  late final GeneratedColumn<String> prep = GeneratedColumn<String>(
    'prep',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
    'calories',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteinMeta = const VerificationMeta(
    'protein',
  );
  @override
  late final GeneratedColumn<int> protein = GeneratedColumn<int>(
    'protein',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbsMeta = const VerificationMeta('carbs');
  @override
  late final GeneratedColumn<int> carbs = GeneratedColumn<int>(
    'carbs',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatMeta = const VerificationMeta('fat');
  @override
  late final GeneratedColumn<int> fat = GeneratedColumn<int>(
    'fat',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _reactionMeta = const VerificationMeta(
    'reaction',
  );
  @override
  late final GeneratedColumn<int> reaction = GeneratedColumn<int>(
    'reaction',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mealId,
    name,
    portion,
    prep,
    calories,
    protein,
    carbs,
    fat,
    reaction,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mealIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('portion')) {
      context.handle(
        _portionMeta,
        portion.isAcceptableOrUnknown(data['portion']!, _portionMeta),
      );
    }
    if (data.containsKey('prep')) {
      context.handle(
        _prepMeta,
        prep.isAcceptableOrUnknown(data['prep']!, _prepMeta),
      );
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    }
    if (data.containsKey('protein')) {
      context.handle(
        _proteinMeta,
        protein.isAcceptableOrUnknown(data['protein']!, _proteinMeta),
      );
    }
    if (data.containsKey('carbs')) {
      context.handle(
        _carbsMeta,
        carbs.isAcceptableOrUnknown(data['carbs']!, _carbsMeta),
      );
    }
    if (data.containsKey('fat')) {
      context.handle(
        _fatMeta,
        fat.isAcceptableOrUnknown(data['fat']!, _fatMeta),
      );
    }
    if (data.containsKey('reaction')) {
      context.handle(
        _reactionMeta,
        reaction.isAcceptableOrUnknown(data['reaction']!, _reactionMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meal_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      portion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portion'],
      ),
      prep: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prep'],
      ),
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories'],
      ),
      protein: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protein'],
      ),
      carbs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carbs'],
      ),
      fat: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fat'],
      ),
      reaction: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reaction'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $FoodItemsTable createAlias(String alias) {
    return $FoodItemsTable(attachedDatabase, alias);
  }
}

class FoodItem extends DataClass implements Insertable<FoodItem> {
  final int id;
  final int mealId;
  final String name;
  final String? portion;
  final String? prep;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fat;
  final int reaction;
  final String? notes;
  const FoodItem({
    required this.id,
    required this.mealId,
    required this.name,
    this.portion,
    this.prep,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    required this.reaction,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meal_id'] = Variable<int>(mealId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || portion != null) {
      map['portion'] = Variable<String>(portion);
    }
    if (!nullToAbsent || prep != null) {
      map['prep'] = Variable<String>(prep);
    }
    if (!nullToAbsent || calories != null) {
      map['calories'] = Variable<int>(calories);
    }
    if (!nullToAbsent || protein != null) {
      map['protein'] = Variable<int>(protein);
    }
    if (!nullToAbsent || carbs != null) {
      map['carbs'] = Variable<int>(carbs);
    }
    if (!nullToAbsent || fat != null) {
      map['fat'] = Variable<int>(fat);
    }
    map['reaction'] = Variable<int>(reaction);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  FoodItemsCompanion toCompanion(bool nullToAbsent) {
    return FoodItemsCompanion(
      id: Value(id),
      mealId: Value(mealId),
      name: Value(name),
      portion: portion == null && nullToAbsent
          ? const Value.absent()
          : Value(portion),
      prep: prep == null && nullToAbsent ? const Value.absent() : Value(prep),
      calories: calories == null && nullToAbsent
          ? const Value.absent()
          : Value(calories),
      protein: protein == null && nullToAbsent
          ? const Value.absent()
          : Value(protein),
      carbs: carbs == null && nullToAbsent
          ? const Value.absent()
          : Value(carbs),
      fat: fat == null && nullToAbsent ? const Value.absent() : Value(fat),
      reaction: Value(reaction),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory FoodItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodItem(
      id: serializer.fromJson<int>(json['id']),
      mealId: serializer.fromJson<int>(json['mealId']),
      name: serializer.fromJson<String>(json['name']),
      portion: serializer.fromJson<String?>(json['portion']),
      prep: serializer.fromJson<String?>(json['prep']),
      calories: serializer.fromJson<int?>(json['calories']),
      protein: serializer.fromJson<int?>(json['protein']),
      carbs: serializer.fromJson<int?>(json['carbs']),
      fat: serializer.fromJson<int?>(json['fat']),
      reaction: serializer.fromJson<int>(json['reaction']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mealId': serializer.toJson<int>(mealId),
      'name': serializer.toJson<String>(name),
      'portion': serializer.toJson<String?>(portion),
      'prep': serializer.toJson<String?>(prep),
      'calories': serializer.toJson<int?>(calories),
      'protein': serializer.toJson<int?>(protein),
      'carbs': serializer.toJson<int?>(carbs),
      'fat': serializer.toJson<int?>(fat),
      'reaction': serializer.toJson<int>(reaction),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  FoodItem copyWith({
    int? id,
    int? mealId,
    String? name,
    Value<String?> portion = const Value.absent(),
    Value<String?> prep = const Value.absent(),
    Value<int?> calories = const Value.absent(),
    Value<int?> protein = const Value.absent(),
    Value<int?> carbs = const Value.absent(),
    Value<int?> fat = const Value.absent(),
    int? reaction,
    Value<String?> notes = const Value.absent(),
  }) => FoodItem(
    id: id ?? this.id,
    mealId: mealId ?? this.mealId,
    name: name ?? this.name,
    portion: portion.present ? portion.value : this.portion,
    prep: prep.present ? prep.value : this.prep,
    calories: calories.present ? calories.value : this.calories,
    protein: protein.present ? protein.value : this.protein,
    carbs: carbs.present ? carbs.value : this.carbs,
    fat: fat.present ? fat.value : this.fat,
    reaction: reaction ?? this.reaction,
    notes: notes.present ? notes.value : this.notes,
  );
  FoodItem copyWithCompanion(FoodItemsCompanion data) {
    return FoodItem(
      id: data.id.present ? data.id.value : this.id,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      name: data.name.present ? data.name.value : this.name,
      portion: data.portion.present ? data.portion.value : this.portion,
      prep: data.prep.present ? data.prep.value : this.prep,
      calories: data.calories.present ? data.calories.value : this.calories,
      protein: data.protein.present ? data.protein.value : this.protein,
      carbs: data.carbs.present ? data.carbs.value : this.carbs,
      fat: data.fat.present ? data.fat.value : this.fat,
      reaction: data.reaction.present ? data.reaction.value : this.reaction,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodItem(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('name: $name, ')
          ..write('portion: $portion, ')
          ..write('prep: $prep, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('reaction: $reaction, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mealId,
    name,
    portion,
    prep,
    calories,
    protein,
    carbs,
    fat,
    reaction,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodItem &&
          other.id == this.id &&
          other.mealId == this.mealId &&
          other.name == this.name &&
          other.portion == this.portion &&
          other.prep == this.prep &&
          other.calories == this.calories &&
          other.protein == this.protein &&
          other.carbs == this.carbs &&
          other.fat == this.fat &&
          other.reaction == this.reaction &&
          other.notes == this.notes);
}

class FoodItemsCompanion extends UpdateCompanion<FoodItem> {
  final Value<int> id;
  final Value<int> mealId;
  final Value<String> name;
  final Value<String?> portion;
  final Value<String?> prep;
  final Value<int?> calories;
  final Value<int?> protein;
  final Value<int?> carbs;
  final Value<int?> fat;
  final Value<int> reaction;
  final Value<String?> notes;
  const FoodItemsCompanion({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    this.name = const Value.absent(),
    this.portion = const Value.absent(),
    this.prep = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fat = const Value.absent(),
    this.reaction = const Value.absent(),
    this.notes = const Value.absent(),
  });
  FoodItemsCompanion.insert({
    this.id = const Value.absent(),
    required int mealId,
    required String name,
    this.portion = const Value.absent(),
    this.prep = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fat = const Value.absent(),
    this.reaction = const Value.absent(),
    this.notes = const Value.absent(),
  }) : mealId = Value(mealId),
       name = Value(name);
  static Insertable<FoodItem> custom({
    Expression<int>? id,
    Expression<int>? mealId,
    Expression<String>? name,
    Expression<String>? portion,
    Expression<String>? prep,
    Expression<int>? calories,
    Expression<int>? protein,
    Expression<int>? carbs,
    Expression<int>? fat,
    Expression<int>? reaction,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mealId != null) 'meal_id': mealId,
      if (name != null) 'name': name,
      if (portion != null) 'portion': portion,
      if (prep != null) 'prep': prep,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fat != null) 'fat': fat,
      if (reaction != null) 'reaction': reaction,
      if (notes != null) 'notes': notes,
    });
  }

  FoodItemsCompanion copyWith({
    Value<int>? id,
    Value<int>? mealId,
    Value<String>? name,
    Value<String?>? portion,
    Value<String?>? prep,
    Value<int?>? calories,
    Value<int?>? protein,
    Value<int?>? carbs,
    Value<int?>? fat,
    Value<int>? reaction,
    Value<String?>? notes,
  }) {
    return FoodItemsCompanion(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      name: name ?? this.name,
      portion: portion ?? this.portion,
      prep: prep ?? this.prep,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      reaction: reaction ?? this.reaction,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<int>(mealId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (portion.present) {
      map['portion'] = Variable<String>(portion.value);
    }
    if (prep.present) {
      map['prep'] = Variable<String>(prep.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (protein.present) {
      map['protein'] = Variable<int>(protein.value);
    }
    if (carbs.present) {
      map['carbs'] = Variable<int>(carbs.value);
    }
    if (fat.present) {
      map['fat'] = Variable<int>(fat.value);
    }
    if (reaction.present) {
      map['reaction'] = Variable<int>(reaction.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodItemsCompanion(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('name: $name, ')
          ..write('portion: $portion, ')
          ..write('prep: $prep, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fat: $fat, ')
          ..write('reaction: $reaction, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $IngredientsTable extends Ingredients
    with TableInfo<$IngredientsTable, Ingredient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _foodItemIdMeta = const VerificationMeta(
    'foodItemId',
  );
  @override
  late final GeneratedColumn<int> foodItemId = GeneratedColumn<int>(
    'food_item_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES food_items (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<String> quantity = GeneratedColumn<String>(
    'quantity',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, foodItemId, name, quantity, unit];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingredients';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ingredient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('food_item_id')) {
      context.handle(
        _foodItemIdMeta,
        foodItemId.isAcceptableOrUnknown(
          data['food_item_id']!,
          _foodItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_foodItemIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ingredient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ingredient(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      foodItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_item_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quantity'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
    );
  }

  @override
  $IngredientsTable createAlias(String alias) {
    return $IngredientsTable(attachedDatabase, alias);
  }
}

class Ingredient extends DataClass implements Insertable<Ingredient> {
  final int id;
  final int foodItemId;
  final String name;
  final String? quantity;
  final String? unit;
  const Ingredient({
    required this.id,
    required this.foodItemId,
    required this.name,
    this.quantity,
    this.unit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['food_item_id'] = Variable<int>(foodItemId);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || quantity != null) {
      map['quantity'] = Variable<String>(quantity);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    return map;
  }

  IngredientsCompanion toCompanion(bool nullToAbsent) {
    return IngredientsCompanion(
      id: Value(id),
      foodItemId: Value(foodItemId),
      name: Value(name),
      quantity: quantity == null && nullToAbsent
          ? const Value.absent()
          : Value(quantity),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
    );
  }

  factory Ingredient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ingredient(
      id: serializer.fromJson<int>(json['id']),
      foodItemId: serializer.fromJson<int>(json['foodItemId']),
      name: serializer.fromJson<String>(json['name']),
      quantity: serializer.fromJson<String?>(json['quantity']),
      unit: serializer.fromJson<String?>(json['unit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'foodItemId': serializer.toJson<int>(foodItemId),
      'name': serializer.toJson<String>(name),
      'quantity': serializer.toJson<String?>(quantity),
      'unit': serializer.toJson<String?>(unit),
    };
  }

  Ingredient copyWith({
    int? id,
    int? foodItemId,
    String? name,
    Value<String?> quantity = const Value.absent(),
    Value<String?> unit = const Value.absent(),
  }) => Ingredient(
    id: id ?? this.id,
    foodItemId: foodItemId ?? this.foodItemId,
    name: name ?? this.name,
    quantity: quantity.present ? quantity.value : this.quantity,
    unit: unit.present ? unit.value : this.unit,
  );
  Ingredient copyWithCompanion(IngredientsCompanion data) {
    return Ingredient(
      id: data.id.present ? data.id.value : this.id,
      foodItemId: data.foodItemId.present
          ? data.foodItemId.value
          : this.foodItemId,
      name: data.name.present ? data.name.value : this.name,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ingredient(')
          ..write('id: $id, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, foodItemId, name, quantity, unit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ingredient &&
          other.id == this.id &&
          other.foodItemId == this.foodItemId &&
          other.name == this.name &&
          other.quantity == this.quantity &&
          other.unit == this.unit);
}

class IngredientsCompanion extends UpdateCompanion<Ingredient> {
  final Value<int> id;
  final Value<int> foodItemId;
  final Value<String> name;
  final Value<String?> quantity;
  final Value<String?> unit;
  const IngredientsCompanion({
    this.id = const Value.absent(),
    this.foodItemId = const Value.absent(),
    this.name = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
  });
  IngredientsCompanion.insert({
    this.id = const Value.absent(),
    required int foodItemId,
    required String name,
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
  }) : foodItemId = Value(foodItemId),
       name = Value(name);
  static Insertable<Ingredient> custom({
    Expression<int>? id,
    Expression<int>? foodItemId,
    Expression<String>? name,
    Expression<String>? quantity,
    Expression<String>? unit,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (foodItemId != null) 'food_item_id': foodItemId,
      if (name != null) 'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
    });
  }

  IngredientsCompanion copyWith({
    Value<int>? id,
    Value<int>? foodItemId,
    Value<String>? name,
    Value<String?>? quantity,
    Value<String?>? unit,
  }) {
    return IngredientsCompanion(
      id: id ?? this.id,
      foodItemId: foodItemId ?? this.foodItemId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (foodItemId.present) {
      map['food_item_id'] = Variable<int>(foodItemId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<String>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngredientsCompanion(')
          ..write('id: $id, ')
          ..write('foodItemId: $foodItemId, ')
          ..write('name: $name, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }
}

class $ReactionLogsTable extends ReactionLogs
    with TableInfo<$ReactionLogsTable, ReactionLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReactionLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<int> mealId = GeneratedColumn<int>(
    'meal_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkinTimeMeta = const VerificationMeta(
    'checkinTime',
  );
  @override
  late final GeneratedColumn<DateTime> checkinTime = GeneratedColumn<DateTime>(
    'checkin_time',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symptomsMeta = const VerificationMeta(
    'symptoms',
  );
  @override
  late final GeneratedColumn<String> symptoms = GeneratedColumn<String>(
    'symptoms',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _severityMeta = const VerificationMeta(
    'severity',
  );
  @override
  late final GeneratedColumn<int> severity = GeneratedColumn<int>(
    'severity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mealId,
    checkinTime,
    symptoms,
    severity,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reaction_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReactionLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    }
    if (data.containsKey('checkin_time')) {
      context.handle(
        _checkinTimeMeta,
        checkinTime.isAcceptableOrUnknown(
          data['checkin_time']!,
          _checkinTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_checkinTimeMeta);
    }
    if (data.containsKey('symptoms')) {
      context.handle(
        _symptomsMeta,
        symptoms.isAcceptableOrUnknown(data['symptoms']!, _symptomsMeta),
      );
    } else if (isInserting) {
      context.missing(_symptomsMeta);
    }
    if (data.containsKey('severity')) {
      context.handle(
        _severityMeta,
        severity.isAcceptableOrUnknown(data['severity']!, _severityMeta),
      );
    } else if (isInserting) {
      context.missing(_severityMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReactionLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReactionLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meal_id'],
      ),
      checkinTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}checkin_time'],
      )!,
      symptoms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symptoms'],
      )!,
      severity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}severity'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $ReactionLogsTable createAlias(String alias) {
    return $ReactionLogsTable(attachedDatabase, alias);
  }
}

class ReactionLog extends DataClass implements Insertable<ReactionLog> {
  final int id;
  final int? mealId;
  final DateTime checkinTime;
  final String symptoms;
  final int severity;
  final String? notes;
  const ReactionLog({
    required this.id,
    this.mealId,
    required this.checkinTime,
    required this.symptoms,
    required this.severity,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || mealId != null) {
      map['meal_id'] = Variable<int>(mealId);
    }
    map['checkin_time'] = Variable<DateTime>(checkinTime);
    map['symptoms'] = Variable<String>(symptoms);
    map['severity'] = Variable<int>(severity);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ReactionLogsCompanion toCompanion(bool nullToAbsent) {
    return ReactionLogsCompanion(
      id: Value(id),
      mealId: mealId == null && nullToAbsent
          ? const Value.absent()
          : Value(mealId),
      checkinTime: Value(checkinTime),
      symptoms: Value(symptoms),
      severity: Value(severity),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory ReactionLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReactionLog(
      id: serializer.fromJson<int>(json['id']),
      mealId: serializer.fromJson<int?>(json['mealId']),
      checkinTime: serializer.fromJson<DateTime>(json['checkinTime']),
      symptoms: serializer.fromJson<String>(json['symptoms']),
      severity: serializer.fromJson<int>(json['severity']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mealId': serializer.toJson<int?>(mealId),
      'checkinTime': serializer.toJson<DateTime>(checkinTime),
      'symptoms': serializer.toJson<String>(symptoms),
      'severity': serializer.toJson<int>(severity),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  ReactionLog copyWith({
    int? id,
    Value<int?> mealId = const Value.absent(),
    DateTime? checkinTime,
    String? symptoms,
    int? severity,
    Value<String?> notes = const Value.absent(),
  }) => ReactionLog(
    id: id ?? this.id,
    mealId: mealId.present ? mealId.value : this.mealId,
    checkinTime: checkinTime ?? this.checkinTime,
    symptoms: symptoms ?? this.symptoms,
    severity: severity ?? this.severity,
    notes: notes.present ? notes.value : this.notes,
  );
  ReactionLog copyWithCompanion(ReactionLogsCompanion data) {
    return ReactionLog(
      id: data.id.present ? data.id.value : this.id,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      checkinTime: data.checkinTime.present
          ? data.checkinTime.value
          : this.checkinTime,
      symptoms: data.symptoms.present ? data.symptoms.value : this.symptoms,
      severity: data.severity.present ? data.severity.value : this.severity,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReactionLog(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('checkinTime: $checkinTime, ')
          ..write('symptoms: $symptoms, ')
          ..write('severity: $severity, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, mealId, checkinTime, symptoms, severity, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReactionLog &&
          other.id == this.id &&
          other.mealId == this.mealId &&
          other.checkinTime == this.checkinTime &&
          other.symptoms == this.symptoms &&
          other.severity == this.severity &&
          other.notes == this.notes);
}

class ReactionLogsCompanion extends UpdateCompanion<ReactionLog> {
  final Value<int> id;
  final Value<int?> mealId;
  final Value<DateTime> checkinTime;
  final Value<String> symptoms;
  final Value<int> severity;
  final Value<String?> notes;
  const ReactionLogsCompanion({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    this.checkinTime = const Value.absent(),
    this.symptoms = const Value.absent(),
    this.severity = const Value.absent(),
    this.notes = const Value.absent(),
  });
  ReactionLogsCompanion.insert({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    required DateTime checkinTime,
    required String symptoms,
    required int severity,
    this.notes = const Value.absent(),
  }) : checkinTime = Value(checkinTime),
       symptoms = Value(symptoms),
       severity = Value(severity);
  static Insertable<ReactionLog> custom({
    Expression<int>? id,
    Expression<int>? mealId,
    Expression<DateTime>? checkinTime,
    Expression<String>? symptoms,
    Expression<int>? severity,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mealId != null) 'meal_id': mealId,
      if (checkinTime != null) 'checkin_time': checkinTime,
      if (symptoms != null) 'symptoms': symptoms,
      if (severity != null) 'severity': severity,
      if (notes != null) 'notes': notes,
    });
  }

  ReactionLogsCompanion copyWith({
    Value<int>? id,
    Value<int?>? mealId,
    Value<DateTime>? checkinTime,
    Value<String>? symptoms,
    Value<int>? severity,
    Value<String?>? notes,
  }) {
    return ReactionLogsCompanion(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      checkinTime: checkinTime ?? this.checkinTime,
      symptoms: symptoms ?? this.symptoms,
      severity: severity ?? this.severity,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<int>(mealId.value);
    }
    if (checkinTime.present) {
      map['checkin_time'] = Variable<DateTime>(checkinTime.value);
    }
    if (symptoms.present) {
      map['symptoms'] = Variable<String>(symptoms.value);
    }
    if (severity.present) {
      map['severity'] = Variable<int>(severity.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReactionLogsCompanion(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('checkinTime: $checkinTime, ')
          ..write('symptoms: $symptoms, ')
          ..write('severity: $severity, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $FoodMemoriesTable extends FoodMemories
    with TableInfo<$FoodMemoriesTable, FoodMemory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodMemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _foodNameMeta = const VerificationMeta(
    'foodName',
  );
  @override
  late final GeneratedColumn<String> foodName = GeneratedColumn<String>(
    'food_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _reactionPatternMeta = const VerificationMeta(
    'reactionPattern',
  );
  @override
  late final GeneratedColumn<String> reactionPattern = GeneratedColumn<String>(
    'reaction_pattern',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurrencesMeta = const VerificationMeta(
    'occurrences',
  );
  @override
  late final GeneratedColumn<int> occurrences = GeneratedColumn<int>(
    'occurrences',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<DateTime> lastSeen = GeneratedColumn<DateTime>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _flaggedMeta = const VerificationMeta(
    'flagged',
  );
  @override
  late final GeneratedColumn<bool> flagged = GeneratedColumn<bool>(
    'flagged',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("flagged" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    foodName,
    reactionPattern,
    occurrences,
    lastSeen,
    flagged,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'food_memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<FoodMemory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('food_name')) {
      context.handle(
        _foodNameMeta,
        foodName.isAcceptableOrUnknown(data['food_name']!, _foodNameMeta),
      );
    } else if (isInserting) {
      context.missing(_foodNameMeta);
    }
    if (data.containsKey('reaction_pattern')) {
      context.handle(
        _reactionPatternMeta,
        reactionPattern.isAcceptableOrUnknown(
          data['reaction_pattern']!,
          _reactionPatternMeta,
        ),
      );
    }
    if (data.containsKey('occurrences')) {
      context.handle(
        _occurrencesMeta,
        occurrences.isAcceptableOrUnknown(
          data['occurrences']!,
          _occurrencesMeta,
        ),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    if (data.containsKey('flagged')) {
      context.handle(
        _flaggedMeta,
        flagged.isAcceptableOrUnknown(data['flagged']!, _flaggedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FoodMemory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FoodMemory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      foodName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}food_name'],
      )!,
      reactionPattern: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reaction_pattern'],
      ),
      occurrences: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}occurrences'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_seen'],
      )!,
      flagged: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}flagged'],
      )!,
    );
  }

  @override
  $FoodMemoriesTable createAlias(String alias) {
    return $FoodMemoriesTable(attachedDatabase, alias);
  }
}

class FoodMemory extends DataClass implements Insertable<FoodMemory> {
  final int id;
  final String foodName;
  final String? reactionPattern;
  final int occurrences;
  final DateTime lastSeen;
  final bool flagged;
  const FoodMemory({
    required this.id,
    required this.foodName,
    this.reactionPattern,
    required this.occurrences,
    required this.lastSeen,
    required this.flagged,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['food_name'] = Variable<String>(foodName);
    if (!nullToAbsent || reactionPattern != null) {
      map['reaction_pattern'] = Variable<String>(reactionPattern);
    }
    map['occurrences'] = Variable<int>(occurrences);
    map['last_seen'] = Variable<DateTime>(lastSeen);
    map['flagged'] = Variable<bool>(flagged);
    return map;
  }

  FoodMemoriesCompanion toCompanion(bool nullToAbsent) {
    return FoodMemoriesCompanion(
      id: Value(id),
      foodName: Value(foodName),
      reactionPattern: reactionPattern == null && nullToAbsent
          ? const Value.absent()
          : Value(reactionPattern),
      occurrences: Value(occurrences),
      lastSeen: Value(lastSeen),
      flagged: Value(flagged),
    );
  }

  factory FoodMemory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FoodMemory(
      id: serializer.fromJson<int>(json['id']),
      foodName: serializer.fromJson<String>(json['foodName']),
      reactionPattern: serializer.fromJson<String?>(json['reactionPattern']),
      occurrences: serializer.fromJson<int>(json['occurrences']),
      lastSeen: serializer.fromJson<DateTime>(json['lastSeen']),
      flagged: serializer.fromJson<bool>(json['flagged']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'foodName': serializer.toJson<String>(foodName),
      'reactionPattern': serializer.toJson<String?>(reactionPattern),
      'occurrences': serializer.toJson<int>(occurrences),
      'lastSeen': serializer.toJson<DateTime>(lastSeen),
      'flagged': serializer.toJson<bool>(flagged),
    };
  }

  FoodMemory copyWith({
    int? id,
    String? foodName,
    Value<String?> reactionPattern = const Value.absent(),
    int? occurrences,
    DateTime? lastSeen,
    bool? flagged,
  }) => FoodMemory(
    id: id ?? this.id,
    foodName: foodName ?? this.foodName,
    reactionPattern: reactionPattern.present
        ? reactionPattern.value
        : this.reactionPattern,
    occurrences: occurrences ?? this.occurrences,
    lastSeen: lastSeen ?? this.lastSeen,
    flagged: flagged ?? this.flagged,
  );
  FoodMemory copyWithCompanion(FoodMemoriesCompanion data) {
    return FoodMemory(
      id: data.id.present ? data.id.value : this.id,
      foodName: data.foodName.present ? data.foodName.value : this.foodName,
      reactionPattern: data.reactionPattern.present
          ? data.reactionPattern.value
          : this.reactionPattern,
      occurrences: data.occurrences.present
          ? data.occurrences.value
          : this.occurrences,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      flagged: data.flagged.present ? data.flagged.value : this.flagged,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FoodMemory(')
          ..write('id: $id, ')
          ..write('foodName: $foodName, ')
          ..write('reactionPattern: $reactionPattern, ')
          ..write('occurrences: $occurrences, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('flagged: $flagged')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    foodName,
    reactionPattern,
    occurrences,
    lastSeen,
    flagged,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FoodMemory &&
          other.id == this.id &&
          other.foodName == this.foodName &&
          other.reactionPattern == this.reactionPattern &&
          other.occurrences == this.occurrences &&
          other.lastSeen == this.lastSeen &&
          other.flagged == this.flagged);
}

class FoodMemoriesCompanion extends UpdateCompanion<FoodMemory> {
  final Value<int> id;
  final Value<String> foodName;
  final Value<String?> reactionPattern;
  final Value<int> occurrences;
  final Value<DateTime> lastSeen;
  final Value<bool> flagged;
  const FoodMemoriesCompanion({
    this.id = const Value.absent(),
    this.foodName = const Value.absent(),
    this.reactionPattern = const Value.absent(),
    this.occurrences = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.flagged = const Value.absent(),
  });
  FoodMemoriesCompanion.insert({
    this.id = const Value.absent(),
    required String foodName,
    this.reactionPattern = const Value.absent(),
    this.occurrences = const Value.absent(),
    required DateTime lastSeen,
    this.flagged = const Value.absent(),
  }) : foodName = Value(foodName),
       lastSeen = Value(lastSeen);
  static Insertable<FoodMemory> custom({
    Expression<int>? id,
    Expression<String>? foodName,
    Expression<String>? reactionPattern,
    Expression<int>? occurrences,
    Expression<DateTime>? lastSeen,
    Expression<bool>? flagged,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (foodName != null) 'food_name': foodName,
      if (reactionPattern != null) 'reaction_pattern': reactionPattern,
      if (occurrences != null) 'occurrences': occurrences,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (flagged != null) 'flagged': flagged,
    });
  }

  FoodMemoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? foodName,
    Value<String?>? reactionPattern,
    Value<int>? occurrences,
    Value<DateTime>? lastSeen,
    Value<bool>? flagged,
  }) {
    return FoodMemoriesCompanion(
      id: id ?? this.id,
      foodName: foodName ?? this.foodName,
      reactionPattern: reactionPattern ?? this.reactionPattern,
      occurrences: occurrences ?? this.occurrences,
      lastSeen: lastSeen ?? this.lastSeen,
      flagged: flagged ?? this.flagged,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (foodName.present) {
      map['food_name'] = Variable<String>(foodName.value);
    }
    if (reactionPattern.present) {
      map['reaction_pattern'] = Variable<String>(reactionPattern.value);
    }
    if (occurrences.present) {
      map['occurrences'] = Variable<int>(occurrences.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<DateTime>(lastSeen.value);
    }
    if (flagged.present) {
      map['flagged'] = Variable<bool>(flagged.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodMemoriesCompanion(')
          ..write('id: $id, ')
          ..write('foodName: $foodName, ')
          ..write('reactionPattern: $reactionPattern, ')
          ..write('occurrences: $occurrences, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('flagged: $flagged')
          ..write(')'))
        .toString();
  }
}

class $MedicationsTable extends Medications
    with TableInfo<$MedicationsTable, Medication> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MedicationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _doseMeta = const VerificationMeta('dose');
  @override
  late final GeneratedColumn<double> dose = GeneratedColumn<double>(
    'dose',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _routeMeta = const VerificationMeta('route');
  @override
  late final GeneratedColumn<String> route = GeneratedColumn<String>(
    'route',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _checkinDelayMinutesMeta =
      const VerificationMeta('checkinDelayMinutes');
  @override
  late final GeneratedColumn<int> checkinDelayMinutes = GeneratedColumn<int>(
    'checkin_delay_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawInputMeta = const VerificationMeta(
    'rawInput',
  );
  @override
  late final GeneratedColumn<String> rawInput = GeneratedColumn<String>(
    'raw_input',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _imageDataMeta = const VerificationMeta(
    'imageData',
  );
  @override
  late final GeneratedColumn<Uint8List> imageData = GeneratedColumn<Uint8List>(
    'image_data',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    time,
    name,
    dose,
    unit,
    route,
    checkinDelayMinutes,
    rawInput,
    notes,
    imageData,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'medications';
  @override
  VerificationContext validateIntegrity(
    Insertable<Medication> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('dose')) {
      context.handle(
        _doseMeta,
        dose.isAcceptableOrUnknown(data['dose']!, _doseMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('route')) {
      context.handle(
        _routeMeta,
        route.isAcceptableOrUnknown(data['route']!, _routeMeta),
      );
    }
    if (data.containsKey('checkin_delay_minutes')) {
      context.handle(
        _checkinDelayMinutesMeta,
        checkinDelayMinutes.isAcceptableOrUnknown(
          data['checkin_delay_minutes']!,
          _checkinDelayMinutesMeta,
        ),
      );
    }
    if (data.containsKey('raw_input')) {
      context.handle(
        _rawInputMeta,
        rawInput.isAcceptableOrUnknown(data['raw_input']!, _rawInputMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('image_data')) {
      context.handle(
        _imageDataMeta,
        imageData.isAcceptableOrUnknown(data['image_data']!, _imageDataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Medication map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Medication(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      dose: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}dose'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      ),
      route: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}route'],
      ),
      checkinDelayMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checkin_delay_minutes'],
      ),
      rawInput: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_input'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      imageData: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}image_data'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MedicationsTable createAlias(String alias) {
    return $MedicationsTable(attachedDatabase, alias);
  }
}

class Medication extends DataClass implements Insertable<Medication> {
  final int id;
  final DateTime date;
  final String time;
  final String name;
  final double? dose;
  final String? unit;
  final String? route;
  final int? checkinDelayMinutes;
  final String? rawInput;
  final String? notes;
  final Uint8List? imageData;
  final DateTime createdAt;
  const Medication({
    required this.id,
    required this.date,
    required this.time,
    required this.name,
    this.dose,
    this.unit,
    this.route,
    this.checkinDelayMinutes,
    this.rawInput,
    this.notes,
    this.imageData,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['time'] = Variable<String>(time);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || dose != null) {
      map['dose'] = Variable<double>(dose);
    }
    if (!nullToAbsent || unit != null) {
      map['unit'] = Variable<String>(unit);
    }
    if (!nullToAbsent || route != null) {
      map['route'] = Variable<String>(route);
    }
    if (!nullToAbsent || checkinDelayMinutes != null) {
      map['checkin_delay_minutes'] = Variable<int>(checkinDelayMinutes);
    }
    if (!nullToAbsent || rawInput != null) {
      map['raw_input'] = Variable<String>(rawInput);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || imageData != null) {
      map['image_data'] = Variable<Uint8List>(imageData);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  MedicationsCompanion toCompanion(bool nullToAbsent) {
    return MedicationsCompanion(
      id: Value(id),
      date: Value(date),
      time: Value(time),
      name: Value(name),
      dose: dose == null && nullToAbsent ? const Value.absent() : Value(dose),
      unit: unit == null && nullToAbsent ? const Value.absent() : Value(unit),
      route: route == null && nullToAbsent
          ? const Value.absent()
          : Value(route),
      checkinDelayMinutes: checkinDelayMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(checkinDelayMinutes),
      rawInput: rawInput == null && nullToAbsent
          ? const Value.absent()
          : Value(rawInput),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      imageData: imageData == null && nullToAbsent
          ? const Value.absent()
          : Value(imageData),
      createdAt: Value(createdAt),
    );
  }

  factory Medication.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Medication(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      time: serializer.fromJson<String>(json['time']),
      name: serializer.fromJson<String>(json['name']),
      dose: serializer.fromJson<double?>(json['dose']),
      unit: serializer.fromJson<String?>(json['unit']),
      route: serializer.fromJson<String?>(json['route']),
      checkinDelayMinutes: serializer.fromJson<int?>(
        json['checkinDelayMinutes'],
      ),
      rawInput: serializer.fromJson<String?>(json['rawInput']),
      notes: serializer.fromJson<String?>(json['notes']),
      imageData: serializer.fromJson<Uint8List?>(json['imageData']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'time': serializer.toJson<String>(time),
      'name': serializer.toJson<String>(name),
      'dose': serializer.toJson<double?>(dose),
      'unit': serializer.toJson<String?>(unit),
      'route': serializer.toJson<String?>(route),
      'checkinDelayMinutes': serializer.toJson<int?>(checkinDelayMinutes),
      'rawInput': serializer.toJson<String?>(rawInput),
      'notes': serializer.toJson<String?>(notes),
      'imageData': serializer.toJson<Uint8List?>(imageData),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Medication copyWith({
    int? id,
    DateTime? date,
    String? time,
    String? name,
    Value<double?> dose = const Value.absent(),
    Value<String?> unit = const Value.absent(),
    Value<String?> route = const Value.absent(),
    Value<int?> checkinDelayMinutes = const Value.absent(),
    Value<String?> rawInput = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<Uint8List?> imageData = const Value.absent(),
    DateTime? createdAt,
  }) => Medication(
    id: id ?? this.id,
    date: date ?? this.date,
    time: time ?? this.time,
    name: name ?? this.name,
    dose: dose.present ? dose.value : this.dose,
    unit: unit.present ? unit.value : this.unit,
    route: route.present ? route.value : this.route,
    checkinDelayMinutes: checkinDelayMinutes.present
        ? checkinDelayMinutes.value
        : this.checkinDelayMinutes,
    rawInput: rawInput.present ? rawInput.value : this.rawInput,
    notes: notes.present ? notes.value : this.notes,
    imageData: imageData.present ? imageData.value : this.imageData,
    createdAt: createdAt ?? this.createdAt,
  );
  Medication copyWithCompanion(MedicationsCompanion data) {
    return Medication(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      time: data.time.present ? data.time.value : this.time,
      name: data.name.present ? data.name.value : this.name,
      dose: data.dose.present ? data.dose.value : this.dose,
      unit: data.unit.present ? data.unit.value : this.unit,
      route: data.route.present ? data.route.value : this.route,
      checkinDelayMinutes: data.checkinDelayMinutes.present
          ? data.checkinDelayMinutes.value
          : this.checkinDelayMinutes,
      rawInput: data.rawInput.present ? data.rawInput.value : this.rawInput,
      notes: data.notes.present ? data.notes.value : this.notes,
      imageData: data.imageData.present ? data.imageData.value : this.imageData,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Medication(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('name: $name, ')
          ..write('dose: $dose, ')
          ..write('unit: $unit, ')
          ..write('route: $route, ')
          ..write('checkinDelayMinutes: $checkinDelayMinutes, ')
          ..write('rawInput: $rawInput, ')
          ..write('notes: $notes, ')
          ..write('imageData: $imageData, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    date,
    time,
    name,
    dose,
    unit,
    route,
    checkinDelayMinutes,
    rawInput,
    notes,
    $driftBlobEquality.hash(imageData),
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Medication &&
          other.id == this.id &&
          other.date == this.date &&
          other.time == this.time &&
          other.name == this.name &&
          other.dose == this.dose &&
          other.unit == this.unit &&
          other.route == this.route &&
          other.checkinDelayMinutes == this.checkinDelayMinutes &&
          other.rawInput == this.rawInput &&
          other.notes == this.notes &&
          $driftBlobEquality.equals(other.imageData, this.imageData) &&
          other.createdAt == this.createdAt);
}

class MedicationsCompanion extends UpdateCompanion<Medication> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> time;
  final Value<String> name;
  final Value<double?> dose;
  final Value<String?> unit;
  final Value<String?> route;
  final Value<int?> checkinDelayMinutes;
  final Value<String?> rawInput;
  final Value<String?> notes;
  final Value<Uint8List?> imageData;
  final Value<DateTime> createdAt;
  const MedicationsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.time = const Value.absent(),
    this.name = const Value.absent(),
    this.dose = const Value.absent(),
    this.unit = const Value.absent(),
    this.route = const Value.absent(),
    this.checkinDelayMinutes = const Value.absent(),
    this.rawInput = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageData = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MedicationsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String time,
    required String name,
    this.dose = const Value.absent(),
    this.unit = const Value.absent(),
    this.route = const Value.absent(),
    this.checkinDelayMinutes = const Value.absent(),
    this.rawInput = const Value.absent(),
    this.notes = const Value.absent(),
    this.imageData = const Value.absent(),
    required DateTime createdAt,
  }) : date = Value(date),
       time = Value(time),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Medication> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? time,
    Expression<String>? name,
    Expression<double>? dose,
    Expression<String>? unit,
    Expression<String>? route,
    Expression<int>? checkinDelayMinutes,
    Expression<String>? rawInput,
    Expression<String>? notes,
    Expression<Uint8List>? imageData,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (time != null) 'time': time,
      if (name != null) 'name': name,
      if (dose != null) 'dose': dose,
      if (unit != null) 'unit': unit,
      if (route != null) 'route': route,
      if (checkinDelayMinutes != null)
        'checkin_delay_minutes': checkinDelayMinutes,
      if (rawInput != null) 'raw_input': rawInput,
      if (notes != null) 'notes': notes,
      if (imageData != null) 'image_data': imageData,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MedicationsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? time,
    Value<String>? name,
    Value<double?>? dose,
    Value<String?>? unit,
    Value<String?>? route,
    Value<int?>? checkinDelayMinutes,
    Value<String?>? rawInput,
    Value<String?>? notes,
    Value<Uint8List?>? imageData,
    Value<DateTime>? createdAt,
  }) {
    return MedicationsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      unit: unit ?? this.unit,
      route: route ?? this.route,
      checkinDelayMinutes: checkinDelayMinutes ?? this.checkinDelayMinutes,
      rawInput: rawInput ?? this.rawInput,
      notes: notes ?? this.notes,
      imageData: imageData ?? this.imageData,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (dose.present) {
      map['dose'] = Variable<double>(dose.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (route.present) {
      map['route'] = Variable<String>(route.value);
    }
    if (checkinDelayMinutes.present) {
      map['checkin_delay_minutes'] = Variable<int>(checkinDelayMinutes.value);
    }
    if (rawInput.present) {
      map['raw_input'] = Variable<String>(rawInput.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (imageData.present) {
      map['image_data'] = Variable<Uint8List>(imageData.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MedicationsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('name: $name, ')
          ..write('dose: $dose, ')
          ..write('unit: $unit, ')
          ..write('route: $route, ')
          ..write('checkinDelayMinutes: $checkinDelayMinutes, ')
          ..write('rawInput: $rawInput, ')
          ..write('notes: $notes, ')
          ..write('imageData: $imageData, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MealFingerprintsTable extends MealFingerprints
    with TableInfo<$MealFingerprintsTable, MealFingerprint> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealFingerprintsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<int> mealId = GeneratedColumn<int>(
    'meal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mealTypeMeta = const VerificationMeta(
    'mealType',
  );
  @override
  late final GeneratedColumn<String> mealType = GeneratedColumn<String>(
    'meal_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _foodsSummaryMeta = const VerificationMeta(
    'foodsSummary',
  );
  @override
  late final GeneratedColumn<String> foodsSummary = GeneratedColumn<String>(
    'foods_summary',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCalsMeta = const VerificationMeta(
    'totalCals',
  );
  @override
  late final GeneratedColumn<int> totalCals = GeneratedColumn<int>(
    'total_cals',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalProteinMeta = const VerificationMeta(
    'totalProtein',
  );
  @override
  late final GeneratedColumn<double> totalProtein = GeneratedColumn<double>(
    'total_protein',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mealId,
    date,
    mealType,
    foodsSummary,
    totalCals,
    totalProtein,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_fingerprints';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealFingerprint> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mealIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('meal_type')) {
      context.handle(
        _mealTypeMeta,
        mealType.isAcceptableOrUnknown(data['meal_type']!, _mealTypeMeta),
      );
    }
    if (data.containsKey('foods_summary')) {
      context.handle(
        _foodsSummaryMeta,
        foodsSummary.isAcceptableOrUnknown(
          data['foods_summary']!,
          _foodsSummaryMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_foodsSummaryMeta);
    }
    if (data.containsKey('total_cals')) {
      context.handle(
        _totalCalsMeta,
        totalCals.isAcceptableOrUnknown(data['total_cals']!, _totalCalsMeta),
      );
    }
    if (data.containsKey('total_protein')) {
      context.handle(
        _totalProteinMeta,
        totalProtein.isAcceptableOrUnknown(
          data['total_protein']!,
          _totalProteinMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealFingerprint map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealFingerprint(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meal_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      mealType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}meal_type'],
      ),
      foodsSummary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foods_summary'],
      )!,
      totalCals: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cals'],
      ),
      totalProtein: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_protein'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $MealFingerprintsTable createAlias(String alias) {
    return $MealFingerprintsTable(attachedDatabase, alias);
  }
}

class MealFingerprint extends DataClass implements Insertable<MealFingerprint> {
  final int id;
  final int mealId;
  final String date;
  final String? mealType;
  final String foodsSummary;
  final int? totalCals;
  final double? totalProtein;
  final int createdAt;
  const MealFingerprint({
    required this.id,
    required this.mealId,
    required this.date,
    this.mealType,
    required this.foodsSummary,
    this.totalCals,
    this.totalProtein,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['meal_id'] = Variable<int>(mealId);
    map['date'] = Variable<String>(date);
    if (!nullToAbsent || mealType != null) {
      map['meal_type'] = Variable<String>(mealType);
    }
    map['foods_summary'] = Variable<String>(foodsSummary);
    if (!nullToAbsent || totalCals != null) {
      map['total_cals'] = Variable<int>(totalCals);
    }
    if (!nullToAbsent || totalProtein != null) {
      map['total_protein'] = Variable<double>(totalProtein);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  MealFingerprintsCompanion toCompanion(bool nullToAbsent) {
    return MealFingerprintsCompanion(
      id: Value(id),
      mealId: Value(mealId),
      date: Value(date),
      mealType: mealType == null && nullToAbsent
          ? const Value.absent()
          : Value(mealType),
      foodsSummary: Value(foodsSummary),
      totalCals: totalCals == null && nullToAbsent
          ? const Value.absent()
          : Value(totalCals),
      totalProtein: totalProtein == null && nullToAbsent
          ? const Value.absent()
          : Value(totalProtein),
      createdAt: Value(createdAt),
    );
  }

  factory MealFingerprint.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealFingerprint(
      id: serializer.fromJson<int>(json['id']),
      mealId: serializer.fromJson<int>(json['mealId']),
      date: serializer.fromJson<String>(json['date']),
      mealType: serializer.fromJson<String?>(json['mealType']),
      foodsSummary: serializer.fromJson<String>(json['foodsSummary']),
      totalCals: serializer.fromJson<int?>(json['totalCals']),
      totalProtein: serializer.fromJson<double?>(json['totalProtein']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mealId': serializer.toJson<int>(mealId),
      'date': serializer.toJson<String>(date),
      'mealType': serializer.toJson<String?>(mealType),
      'foodsSummary': serializer.toJson<String>(foodsSummary),
      'totalCals': serializer.toJson<int?>(totalCals),
      'totalProtein': serializer.toJson<double?>(totalProtein),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  MealFingerprint copyWith({
    int? id,
    int? mealId,
    String? date,
    Value<String?> mealType = const Value.absent(),
    String? foodsSummary,
    Value<int?> totalCals = const Value.absent(),
    Value<double?> totalProtein = const Value.absent(),
    int? createdAt,
  }) => MealFingerprint(
    id: id ?? this.id,
    mealId: mealId ?? this.mealId,
    date: date ?? this.date,
    mealType: mealType.present ? mealType.value : this.mealType,
    foodsSummary: foodsSummary ?? this.foodsSummary,
    totalCals: totalCals.present ? totalCals.value : this.totalCals,
    totalProtein: totalProtein.present ? totalProtein.value : this.totalProtein,
    createdAt: createdAt ?? this.createdAt,
  );
  MealFingerprint copyWithCompanion(MealFingerprintsCompanion data) {
    return MealFingerprint(
      id: data.id.present ? data.id.value : this.id,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      date: data.date.present ? data.date.value : this.date,
      mealType: data.mealType.present ? data.mealType.value : this.mealType,
      foodsSummary: data.foodsSummary.present
          ? data.foodsSummary.value
          : this.foodsSummary,
      totalCals: data.totalCals.present ? data.totalCals.value : this.totalCals,
      totalProtein: data.totalProtein.present
          ? data.totalProtein.value
          : this.totalProtein,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealFingerprint(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('date: $date, ')
          ..write('mealType: $mealType, ')
          ..write('foodsSummary: $foodsSummary, ')
          ..write('totalCals: $totalCals, ')
          ..write('totalProtein: $totalProtein, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    mealId,
    date,
    mealType,
    foodsSummary,
    totalCals,
    totalProtein,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealFingerprint &&
          other.id == this.id &&
          other.mealId == this.mealId &&
          other.date == this.date &&
          other.mealType == this.mealType &&
          other.foodsSummary == this.foodsSummary &&
          other.totalCals == this.totalCals &&
          other.totalProtein == this.totalProtein &&
          other.createdAt == this.createdAt);
}

class MealFingerprintsCompanion extends UpdateCompanion<MealFingerprint> {
  final Value<int> id;
  final Value<int> mealId;
  final Value<String> date;
  final Value<String?> mealType;
  final Value<String> foodsSummary;
  final Value<int?> totalCals;
  final Value<double?> totalProtein;
  final Value<int> createdAt;
  const MealFingerprintsCompanion({
    this.id = const Value.absent(),
    this.mealId = const Value.absent(),
    this.date = const Value.absent(),
    this.mealType = const Value.absent(),
    this.foodsSummary = const Value.absent(),
    this.totalCals = const Value.absent(),
    this.totalProtein = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  MealFingerprintsCompanion.insert({
    this.id = const Value.absent(),
    required int mealId,
    required String date,
    this.mealType = const Value.absent(),
    required String foodsSummary,
    this.totalCals = const Value.absent(),
    this.totalProtein = const Value.absent(),
    required int createdAt,
  }) : mealId = Value(mealId),
       date = Value(date),
       foodsSummary = Value(foodsSummary),
       createdAt = Value(createdAt);
  static Insertable<MealFingerprint> custom({
    Expression<int>? id,
    Expression<int>? mealId,
    Expression<String>? date,
    Expression<String>? mealType,
    Expression<String>? foodsSummary,
    Expression<int>? totalCals,
    Expression<double>? totalProtein,
    Expression<int>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mealId != null) 'meal_id': mealId,
      if (date != null) 'date': date,
      if (mealType != null) 'meal_type': mealType,
      if (foodsSummary != null) 'foods_summary': foodsSummary,
      if (totalCals != null) 'total_cals': totalCals,
      if (totalProtein != null) 'total_protein': totalProtein,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  MealFingerprintsCompanion copyWith({
    Value<int>? id,
    Value<int>? mealId,
    Value<String>? date,
    Value<String?>? mealType,
    Value<String>? foodsSummary,
    Value<int?>? totalCals,
    Value<double?>? totalProtein,
    Value<int>? createdAt,
  }) {
    return MealFingerprintsCompanion(
      id: id ?? this.id,
      mealId: mealId ?? this.mealId,
      date: date ?? this.date,
      mealType: mealType ?? this.mealType,
      foodsSummary: foodsSummary ?? this.foodsSummary,
      totalCals: totalCals ?? this.totalCals,
      totalProtein: totalProtein ?? this.totalProtein,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<int>(mealId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (mealType.present) {
      map['meal_type'] = Variable<String>(mealType.value);
    }
    if (foodsSummary.present) {
      map['foods_summary'] = Variable<String>(foodsSummary.value);
    }
    if (totalCals.present) {
      map['total_cals'] = Variable<int>(totalCals.value);
    }
    if (totalProtein.present) {
      map['total_protein'] = Variable<double>(totalProtein.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealFingerprintsCompanion(')
          ..write('id: $id, ')
          ..write('mealId: $mealId, ')
          ..write('date: $date, ')
          ..write('mealType: $mealType, ')
          ..write('foodsSummary: $foodsSummary, ')
          ..write('totalCals: $totalCals, ')
          ..write('totalProtein: $totalProtein, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $WaterLogsTable extends WaterLogs
    with TableInfo<$WaterLogsTable, WaterLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WaterLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMlMeta = const VerificationMeta(
    'amountMl',
  );
  @override
  late final GeneratedColumn<int> amountMl = GeneratedColumn<int>(
    'amount_ml',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    time,
    amountMl,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'water_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WaterLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('amount_ml')) {
      context.handle(
        _amountMlMeta,
        amountMl.isAcceptableOrUnknown(data['amount_ml']!, _amountMlMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMlMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WaterLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WaterLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      )!,
      amountMl: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_ml'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WaterLogsTable createAlias(String alias) {
    return $WaterLogsTable(attachedDatabase, alias);
  }
}

class WaterLog extends DataClass implements Insertable<WaterLog> {
  final int id;
  final DateTime date;
  final String time;
  final int amountMl;
  final String? notes;
  final DateTime createdAt;
  const WaterLog({
    required this.id,
    required this.date,
    required this.time,
    required this.amountMl,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['time'] = Variable<String>(time);
    map['amount_ml'] = Variable<int>(amountMl);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WaterLogsCompanion toCompanion(bool nullToAbsent) {
    return WaterLogsCompanion(
      id: Value(id),
      date: Value(date),
      time: Value(time),
      amountMl: Value(amountMl),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory WaterLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WaterLog(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      time: serializer.fromJson<String>(json['time']),
      amountMl: serializer.fromJson<int>(json['amountMl']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'time': serializer.toJson<String>(time),
      'amountMl': serializer.toJson<int>(amountMl),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WaterLog copyWith({
    int? id,
    DateTime? date,
    String? time,
    int? amountMl,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => WaterLog(
    id: id ?? this.id,
    date: date ?? this.date,
    time: time ?? this.time,
    amountMl: amountMl ?? this.amountMl,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  WaterLog copyWithCompanion(WaterLogsCompanion data) {
    return WaterLog(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      time: data.time.present ? data.time.value : this.time,
      amountMl: data.amountMl.present ? data.amountMl.value : this.amountMl,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WaterLog(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('amountMl: $amountMl, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, time, amountMl, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaterLog &&
          other.id == this.id &&
          other.date == this.date &&
          other.time == this.time &&
          other.amountMl == this.amountMl &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class WaterLogsCompanion extends UpdateCompanion<WaterLog> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> time;
  final Value<int> amountMl;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const WaterLogsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.time = const Value.absent(),
    this.amountMl = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WaterLogsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String time,
    required int amountMl,
    this.notes = const Value.absent(),
    required DateTime createdAt,
  }) : date = Value(date),
       time = Value(time),
       amountMl = Value(amountMl),
       createdAt = Value(createdAt);
  static Insertable<WaterLog> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? time,
    Expression<int>? amountMl,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (time != null) 'time': time,
      if (amountMl != null) 'amount_ml': amountMl,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WaterLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? time,
    Value<int>? amountMl,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return WaterLogsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      amountMl: amountMl ?? this.amountMl,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (amountMl.present) {
      map['amount_ml'] = Variable<int>(amountMl.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WaterLogsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('amountMl: $amountMl, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $WeightLogsTable extends WeightLogs
    with TableInfo<$WeightLogsTable, WeightLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeightLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _timeMeta = const VerificationMeta('time');
  @override
  late final GeneratedColumn<String> time = GeneratedColumn<String>(
    'time',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _weightValueMeta = const VerificationMeta(
    'weightValue',
  );
  @override
  late final GeneratedColumn<double> weightValue = GeneratedColumn<double>(
    'weight_value',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    date,
    time,
    weightValue,
    unit,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weight_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeightLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('time')) {
      context.handle(
        _timeMeta,
        time.isAcceptableOrUnknown(data['time']!, _timeMeta),
      );
    } else if (isInserting) {
      context.missing(_timeMeta);
    }
    if (data.containsKey('weight_value')) {
      context.handle(
        _weightValueMeta,
        weightValue.isAcceptableOrUnknown(
          data['weight_value']!,
          _weightValueMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_weightValueMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeightLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeightLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      time: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time'],
      )!,
      weightValue: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight_value'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $WeightLogsTable createAlias(String alias) {
    return $WeightLogsTable(attachedDatabase, alias);
  }
}

class WeightLog extends DataClass implements Insertable<WeightLog> {
  final int id;
  final DateTime date;
  final String time;
  final double weightValue;
  final String unit;
  final String? notes;
  final DateTime createdAt;
  const WeightLog({
    required this.id,
    required this.date,
    required this.time,
    required this.weightValue,
    required this.unit,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['time'] = Variable<String>(time);
    map['weight_value'] = Variable<double>(weightValue);
    map['unit'] = Variable<String>(unit);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  WeightLogsCompanion toCompanion(bool nullToAbsent) {
    return WeightLogsCompanion(
      id: Value(id),
      date: Value(date),
      time: Value(time),
      weightValue: Value(weightValue),
      unit: Value(unit),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory WeightLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeightLog(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      time: serializer.fromJson<String>(json['time']),
      weightValue: serializer.fromJson<double>(json['weightValue']),
      unit: serializer.fromJson<String>(json['unit']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'time': serializer.toJson<String>(time),
      'weightValue': serializer.toJson<double>(weightValue),
      'unit': serializer.toJson<String>(unit),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  WeightLog copyWith({
    int? id,
    DateTime? date,
    String? time,
    double? weightValue,
    String? unit,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => WeightLog(
    id: id ?? this.id,
    date: date ?? this.date,
    time: time ?? this.time,
    weightValue: weightValue ?? this.weightValue,
    unit: unit ?? this.unit,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  WeightLog copyWithCompanion(WeightLogsCompanion data) {
    return WeightLog(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      time: data.time.present ? data.time.value : this.time,
      weightValue: data.weightValue.present
          ? data.weightValue.value
          : this.weightValue,
      unit: data.unit.present ? data.unit.value : this.unit,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeightLog(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('weightValue: $weightValue, ')
          ..write('unit: $unit, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, date, time, weightValue, unit, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeightLog &&
          other.id == this.id &&
          other.date == this.date &&
          other.time == this.time &&
          other.weightValue == this.weightValue &&
          other.unit == this.unit &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class WeightLogsCompanion extends UpdateCompanion<WeightLog> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<String> time;
  final Value<double> weightValue;
  final Value<String> unit;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const WeightLogsCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.time = const Value.absent(),
    this.weightValue = const Value.absent(),
    this.unit = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  WeightLogsCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required String time,
    required double weightValue,
    required String unit,
    this.notes = const Value.absent(),
    required DateTime createdAt,
  }) : date = Value(date),
       time = Value(time),
       weightValue = Value(weightValue),
       unit = Value(unit),
       createdAt = Value(createdAt);
  static Insertable<WeightLog> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<String>? time,
    Expression<double>? weightValue,
    Expression<String>? unit,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (time != null) 'time': time,
      if (weightValue != null) 'weight_value': weightValue,
      if (unit != null) 'unit': unit,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  WeightLogsCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<String>? time,
    Value<double>? weightValue,
    Value<String>? unit,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return WeightLogsCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      weightValue: weightValue ?? this.weightValue,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (time.present) {
      map['time'] = Variable<String>(time.value);
    }
    if (weightValue.present) {
      map['weight_value'] = Variable<double>(weightValue.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeightLogsCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('time: $time, ')
          ..write('weightValue: $weightValue, ')
          ..write('unit: $unit, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MealsTable meals = $MealsTable(this);
  late final $FoodItemsTable foodItems = $FoodItemsTable(this);
  late final $IngredientsTable ingredients = $IngredientsTable(this);
  late final $ReactionLogsTable reactionLogs = $ReactionLogsTable(this);
  late final $FoodMemoriesTable foodMemories = $FoodMemoriesTable(this);
  late final $MedicationsTable medications = $MedicationsTable(this);
  late final $MealFingerprintsTable mealFingerprints = $MealFingerprintsTable(
    this,
  );
  late final $WaterLogsTable waterLogs = $WaterLogsTable(this);
  late final $WeightLogsTable weightLogs = $WeightLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    meals,
    foodItems,
    ingredients,
    reactionLogs,
    foodMemories,
    medications,
    mealFingerprints,
    waterLogs,
    weightLogs,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meal_fingerprints', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$MealsTableCreateCompanionBuilder =
    MealsCompanion Function({
      Value<int> id,
      required DateTime date,
      required String time,
      required String mealType,
      Value<String?> overallSymptoms,
      Value<String?> rawInput,
      required DateTime createdAt,
      Value<Uint8List?> imageData,
    });
typedef $$MealsTableUpdateCompanionBuilder =
    MealsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> time,
      Value<String> mealType,
      Value<String?> overallSymptoms,
      Value<String?> rawInput,
      Value<DateTime> createdAt,
      Value<Uint8List?> imageData,
    });

final class $$MealsTableReferences
    extends BaseReferences<_$AppDatabase, $MealsTable, Meal> {
  $$MealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$FoodItemsTable, List<FoodItem>>
  _foodItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.foodItems,
    aliasName: $_aliasNameGenerator(db.meals.id, db.foodItems.mealId),
  );

  $$FoodItemsTableProcessedTableManager get foodItemsRefs {
    final manager = $$FoodItemsTableTableManager(
      $_db,
      $_db.foodItems,
    ).filter((f) => f.mealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_foodItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$MealFingerprintsTable, List<MealFingerprint>>
  _mealFingerprintsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealFingerprints,
    aliasName: $_aliasNameGenerator(db.meals.id, db.mealFingerprints.mealId),
  );

  $$MealFingerprintsTableProcessedTableManager get mealFingerprintsRefs {
    final manager = $$MealFingerprintsTableTableManager(
      $_db,
      $_db.mealFingerprints,
    ).filter((f) => f.mealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _mealFingerprintsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealsTableFilterComposer extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get overallSymptoms => $composableBuilder(
    column: $table.overallSymptoms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawInput => $composableBuilder(
    column: $table.rawInput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get imageData => $composableBuilder(
    column: $table.imageData,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> foodItemsRefs(
    Expression<bool> Function($$FoodItemsTableFilterComposer f) f,
  ) {
    final $$FoodItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableFilterComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> mealFingerprintsRefs(
    Expression<bool> Function($$MealFingerprintsTableFilterComposer f) f,
  ) {
    final $$MealFingerprintsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFingerprints,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFingerprintsTableFilterComposer(
            $db: $db,
            $table: $db.mealFingerprints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get overallSymptoms => $composableBuilder(
    column: $table.overallSymptoms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawInput => $composableBuilder(
    column: $table.rawInput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get imageData => $composableBuilder(
    column: $table.imageData,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get mealType =>
      $composableBuilder(column: $table.mealType, builder: (column) => column);

  GeneratedColumn<String> get overallSymptoms => $composableBuilder(
    column: $table.overallSymptoms,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawInput =>
      $composableBuilder(column: $table.rawInput, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<Uint8List> get imageData =>
      $composableBuilder(column: $table.imageData, builder: (column) => column);

  Expression<T> foodItemsRefs<T extends Object>(
    Expression<T> Function($$FoodItemsTableAnnotationComposer a) f,
  ) {
    final $$FoodItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> mealFingerprintsRefs<T extends Object>(
    Expression<T> Function($$MealFingerprintsTableAnnotationComposer a) f,
  ) {
    final $$MealFingerprintsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealFingerprints,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealFingerprintsTableAnnotationComposer(
            $db: $db,
            $table: $db.mealFingerprints,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealsTable,
          Meal,
          $$MealsTableFilterComposer,
          $$MealsTableOrderingComposer,
          $$MealsTableAnnotationComposer,
          $$MealsTableCreateCompanionBuilder,
          $$MealsTableUpdateCompanionBuilder,
          (Meal, $$MealsTableReferences),
          Meal,
          PrefetchHooks Function({
            bool foodItemsRefs,
            bool mealFingerprintsRefs,
          })
        > {
  $$MealsTableTableManager(_$AppDatabase db, $MealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> time = const Value.absent(),
                Value<String> mealType = const Value.absent(),
                Value<String?> overallSymptoms = const Value.absent(),
                Value<String?> rawInput = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<Uint8List?> imageData = const Value.absent(),
              }) => MealsCompanion(
                id: id,
                date: date,
                time: time,
                mealType: mealType,
                overallSymptoms: overallSymptoms,
                rawInput: rawInput,
                createdAt: createdAt,
                imageData: imageData,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required String time,
                required String mealType,
                Value<String?> overallSymptoms = const Value.absent(),
                Value<String?> rawInput = const Value.absent(),
                required DateTime createdAt,
                Value<Uint8List?> imageData = const Value.absent(),
              }) => MealsCompanion.insert(
                id: id,
                date: date,
                time: time,
                mealType: mealType,
                overallSymptoms: overallSymptoms,
                rawInput: rawInput,
                createdAt: createdAt,
                imageData: imageData,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$MealsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({foodItemsRefs = false, mealFingerprintsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (foodItemsRefs) db.foodItems,
                    if (mealFingerprintsRefs) db.mealFingerprints,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (foodItemsRefs)
                        await $_getPrefetchedData<Meal, $MealsTable, FoodItem>(
                          currentTable: table,
                          referencedTable: $$MealsTableReferences
                              ._foodItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MealsTableReferences(
                                db,
                                table,
                                p0,
                              ).foodItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mealId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (mealFingerprintsRefs)
                        await $_getPrefetchedData<
                          Meal,
                          $MealsTable,
                          MealFingerprint
                        >(
                          currentTable: table,
                          referencedTable: $$MealsTableReferences
                              ._mealFingerprintsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$MealsTableReferences(
                                db,
                                table,
                                p0,
                              ).mealFingerprintsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.mealId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$MealsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealsTable,
      Meal,
      $$MealsTableFilterComposer,
      $$MealsTableOrderingComposer,
      $$MealsTableAnnotationComposer,
      $$MealsTableCreateCompanionBuilder,
      $$MealsTableUpdateCompanionBuilder,
      (Meal, $$MealsTableReferences),
      Meal,
      PrefetchHooks Function({bool foodItemsRefs, bool mealFingerprintsRefs})
    >;
typedef $$FoodItemsTableCreateCompanionBuilder =
    FoodItemsCompanion Function({
      Value<int> id,
      required int mealId,
      required String name,
      Value<String?> portion,
      Value<String?> prep,
      Value<int?> calories,
      Value<int?> protein,
      Value<int?> carbs,
      Value<int?> fat,
      Value<int> reaction,
      Value<String?> notes,
    });
typedef $$FoodItemsTableUpdateCompanionBuilder =
    FoodItemsCompanion Function({
      Value<int> id,
      Value<int> mealId,
      Value<String> name,
      Value<String?> portion,
      Value<String?> prep,
      Value<int?> calories,
      Value<int?> protein,
      Value<int?> carbs,
      Value<int?> fat,
      Value<int> reaction,
      Value<String?> notes,
    });

final class $$FoodItemsTableReferences
    extends BaseReferences<_$AppDatabase, $FoodItemsTable, FoodItem> {
  $$FoodItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MealsTable _mealIdTable(_$AppDatabase db) => db.meals.createAlias(
    $_aliasNameGenerator(db.foodItems.mealId, db.meals.id),
  );

  $$MealsTableProcessedTableManager get mealId {
    final $_column = $_itemColumn<int>('meal_id')!;

    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$IngredientsTable, List<Ingredient>>
  _ingredientsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ingredients,
    aliasName: $_aliasNameGenerator(db.foodItems.id, db.ingredients.foodItemId),
  );

  $$IngredientsTableProcessedTableManager get ingredientsRefs {
    final manager = $$IngredientsTableTableManager(
      $_db,
      $_db.ingredients,
    ).filter((f) => f.foodItemId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_ingredientsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoodItemsTableFilterComposer
    extends Composer<_$AppDatabase, $FoodItemsTable> {
  $$FoodItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portion => $composableBuilder(
    column: $table.portion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prep => $composableBuilder(
    column: $table.prep,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fat => $composableBuilder(
    column: $table.fat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$MealsTableFilterComposer get mealId {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> ingredientsRefs(
    Expression<bool> Function($$IngredientsTableFilterComposer f) f,
  ) {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.foodItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableFilterComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodItemsTable> {
  $$FoodItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portion => $composableBuilder(
    column: $table.portion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prep => $composableBuilder(
    column: $table.prep,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fat => $composableBuilder(
    column: $table.fat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealsTableOrderingComposer get mealId {
    final $$MealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableOrderingComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FoodItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodItemsTable> {
  $$FoodItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get portion =>
      $composableBuilder(column: $table.portion, builder: (column) => column);

  GeneratedColumn<String> get prep =>
      $composableBuilder(column: $table.prep, builder: (column) => column);

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<int> get protein =>
      $composableBuilder(column: $table.protein, builder: (column) => column);

  GeneratedColumn<int> get carbs =>
      $composableBuilder(column: $table.carbs, builder: (column) => column);

  GeneratedColumn<int> get fat =>
      $composableBuilder(column: $table.fat, builder: (column) => column);

  GeneratedColumn<int> get reaction =>
      $composableBuilder(column: $table.reaction, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$MealsTableAnnotationComposer get mealId {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> ingredientsRefs<T extends Object>(
    Expression<T> Function($$IngredientsTableAnnotationComposer a) f,
  ) {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.foodItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableAnnotationComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodItemsTable,
          FoodItem,
          $$FoodItemsTableFilterComposer,
          $$FoodItemsTableOrderingComposer,
          $$FoodItemsTableAnnotationComposer,
          $$FoodItemsTableCreateCompanionBuilder,
          $$FoodItemsTableUpdateCompanionBuilder,
          (FoodItem, $$FoodItemsTableReferences),
          FoodItem,
          PrefetchHooks Function({bool mealId, bool ingredientsRefs})
        > {
  $$FoodItemsTableTableManager(_$AppDatabase db, $FoodItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mealId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> portion = const Value.absent(),
                Value<String?> prep = const Value.absent(),
                Value<int?> calories = const Value.absent(),
                Value<int?> protein = const Value.absent(),
                Value<int?> carbs = const Value.absent(),
                Value<int?> fat = const Value.absent(),
                Value<int> reaction = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => FoodItemsCompanion(
                id: id,
                mealId: mealId,
                name: name,
                portion: portion,
                prep: prep,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                reaction: reaction,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mealId,
                required String name,
                Value<String?> portion = const Value.absent(),
                Value<String?> prep = const Value.absent(),
                Value<int?> calories = const Value.absent(),
                Value<int?> protein = const Value.absent(),
                Value<int?> carbs = const Value.absent(),
                Value<int?> fat = const Value.absent(),
                Value<int> reaction = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => FoodItemsCompanion.insert(
                id: id,
                mealId: mealId,
                name: name,
                portion: portion,
                prep: prep,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                reaction: reaction,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoodItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mealId = false, ingredientsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (ingredientsRefs) db.ingredients],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mealId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mealId,
                                referencedTable: $$FoodItemsTableReferences
                                    ._mealIdTable(db),
                                referencedColumn: $$FoodItemsTableReferences
                                    ._mealIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (ingredientsRefs)
                    await $_getPrefetchedData<
                      FoodItem,
                      $FoodItemsTable,
                      Ingredient
                    >(
                      currentTable: table,
                      referencedTable: $$FoodItemsTableReferences
                          ._ingredientsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FoodItemsTableReferences(
                            db,
                            table,
                            p0,
                          ).ingredientsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.foodItemId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoodItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodItemsTable,
      FoodItem,
      $$FoodItemsTableFilterComposer,
      $$FoodItemsTableOrderingComposer,
      $$FoodItemsTableAnnotationComposer,
      $$FoodItemsTableCreateCompanionBuilder,
      $$FoodItemsTableUpdateCompanionBuilder,
      (FoodItem, $$FoodItemsTableReferences),
      FoodItem,
      PrefetchHooks Function({bool mealId, bool ingredientsRefs})
    >;
typedef $$IngredientsTableCreateCompanionBuilder =
    IngredientsCompanion Function({
      Value<int> id,
      required int foodItemId,
      required String name,
      Value<String?> quantity,
      Value<String?> unit,
    });
typedef $$IngredientsTableUpdateCompanionBuilder =
    IngredientsCompanion Function({
      Value<int> id,
      Value<int> foodItemId,
      Value<String> name,
      Value<String?> quantity,
      Value<String?> unit,
    });

final class $$IngredientsTableReferences
    extends BaseReferences<_$AppDatabase, $IngredientsTable, Ingredient> {
  $$IngredientsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoodItemsTable _foodItemIdTable(_$AppDatabase db) =>
      db.foodItems.createAlias(
        $_aliasNameGenerator(db.ingredients.foodItemId, db.foodItems.id),
      );

  $$FoodItemsTableProcessedTableManager get foodItemId {
    final $_column = $_itemColumn<int>('food_item_id')!;

    final manager = $$FoodItemsTableTableManager(
      $_db,
      $_db.foodItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$IngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  $$FoodItemsTableFilterComposer get foodItemId {
    final $$FoodItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodItemId,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableFilterComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoodItemsTableOrderingComposer get foodItemId {
    final $$FoodItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodItemId,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableOrderingComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  $$FoodItemsTableAnnotationComposer get foodItemId {
    final $$FoodItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodItemId,
      referencedTable: $db.foodItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.foodItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IngredientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IngredientsTable,
          Ingredient,
          $$IngredientsTableFilterComposer,
          $$IngredientsTableOrderingComposer,
          $$IngredientsTableAnnotationComposer,
          $$IngredientsTableCreateCompanionBuilder,
          $$IngredientsTableUpdateCompanionBuilder,
          (Ingredient, $$IngredientsTableReferences),
          Ingredient,
          PrefetchHooks Function({bool foodItemId})
        > {
  $$IngredientsTableTableManager(_$AppDatabase db, $IngredientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngredientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IngredientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> foodItemId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
              }) => IngredientsCompanion(
                id: id,
                foodItemId: foodItemId,
                name: name,
                quantity: quantity,
                unit: unit,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int foodItemId,
                required String name,
                Value<String?> quantity = const Value.absent(),
                Value<String?> unit = const Value.absent(),
              }) => IngredientsCompanion.insert(
                id: id,
                foodItemId: foodItemId,
                name: name,
                quantity: quantity,
                unit: unit,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$IngredientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({foodItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (foodItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.foodItemId,
                                referencedTable: $$IngredientsTableReferences
                                    ._foodItemIdTable(db),
                                referencedColumn: $$IngredientsTableReferences
                                    ._foodItemIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$IngredientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IngredientsTable,
      Ingredient,
      $$IngredientsTableFilterComposer,
      $$IngredientsTableOrderingComposer,
      $$IngredientsTableAnnotationComposer,
      $$IngredientsTableCreateCompanionBuilder,
      $$IngredientsTableUpdateCompanionBuilder,
      (Ingredient, $$IngredientsTableReferences),
      Ingredient,
      PrefetchHooks Function({bool foodItemId})
    >;
typedef $$ReactionLogsTableCreateCompanionBuilder =
    ReactionLogsCompanion Function({
      Value<int> id,
      Value<int?> mealId,
      required DateTime checkinTime,
      required String symptoms,
      required int severity,
      Value<String?> notes,
    });
typedef $$ReactionLogsTableUpdateCompanionBuilder =
    ReactionLogsCompanion Function({
      Value<int> id,
      Value<int?> mealId,
      Value<DateTime> checkinTime,
      Value<String> symptoms,
      Value<int> severity,
      Value<String?> notes,
    });

class $$ReactionLogsTableFilterComposer
    extends Composer<_$AppDatabase, $ReactionLogsTable> {
  $$ReactionLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mealId => $composableBuilder(
    column: $table.mealId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get checkinTime => $composableBuilder(
    column: $table.checkinTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symptoms => $composableBuilder(
    column: $table.symptoms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReactionLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReactionLogsTable> {
  $$ReactionLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mealId => $composableBuilder(
    column: $table.mealId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get checkinTime => $composableBuilder(
    column: $table.checkinTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symptoms => $composableBuilder(
    column: $table.symptoms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get severity => $composableBuilder(
    column: $table.severity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReactionLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReactionLogsTable> {
  $$ReactionLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get mealId =>
      $composableBuilder(column: $table.mealId, builder: (column) => column);

  GeneratedColumn<DateTime> get checkinTime => $composableBuilder(
    column: $table.checkinTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get symptoms =>
      $composableBuilder(column: $table.symptoms, builder: (column) => column);

  GeneratedColumn<int> get severity =>
      $composableBuilder(column: $table.severity, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$ReactionLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReactionLogsTable,
          ReactionLog,
          $$ReactionLogsTableFilterComposer,
          $$ReactionLogsTableOrderingComposer,
          $$ReactionLogsTableAnnotationComposer,
          $$ReactionLogsTableCreateCompanionBuilder,
          $$ReactionLogsTableUpdateCompanionBuilder,
          (
            ReactionLog,
            BaseReferences<_$AppDatabase, $ReactionLogsTable, ReactionLog>,
          ),
          ReactionLog,
          PrefetchHooks Function()
        > {
  $$ReactionLogsTableTableManager(_$AppDatabase db, $ReactionLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReactionLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReactionLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReactionLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> mealId = const Value.absent(),
                Value<DateTime> checkinTime = const Value.absent(),
                Value<String> symptoms = const Value.absent(),
                Value<int> severity = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ReactionLogsCompanion(
                id: id,
                mealId: mealId,
                checkinTime: checkinTime,
                symptoms: symptoms,
                severity: severity,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> mealId = const Value.absent(),
                required DateTime checkinTime,
                required String symptoms,
                required int severity,
                Value<String?> notes = const Value.absent(),
              }) => ReactionLogsCompanion.insert(
                id: id,
                mealId: mealId,
                checkinTime: checkinTime,
                symptoms: symptoms,
                severity: severity,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReactionLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReactionLogsTable,
      ReactionLog,
      $$ReactionLogsTableFilterComposer,
      $$ReactionLogsTableOrderingComposer,
      $$ReactionLogsTableAnnotationComposer,
      $$ReactionLogsTableCreateCompanionBuilder,
      $$ReactionLogsTableUpdateCompanionBuilder,
      (
        ReactionLog,
        BaseReferences<_$AppDatabase, $ReactionLogsTable, ReactionLog>,
      ),
      ReactionLog,
      PrefetchHooks Function()
    >;
typedef $$FoodMemoriesTableCreateCompanionBuilder =
    FoodMemoriesCompanion Function({
      Value<int> id,
      required String foodName,
      Value<String?> reactionPattern,
      Value<int> occurrences,
      required DateTime lastSeen,
      Value<bool> flagged,
    });
typedef $$FoodMemoriesTableUpdateCompanionBuilder =
    FoodMemoriesCompanion Function({
      Value<int> id,
      Value<String> foodName,
      Value<String?> reactionPattern,
      Value<int> occurrences,
      Value<DateTime> lastSeen,
      Value<bool> flagged,
    });

class $$FoodMemoriesTableFilterComposer
    extends Composer<_$AppDatabase, $FoodMemoriesTable> {
  $$FoodMemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reactionPattern => $composableBuilder(
    column: $table.reactionPattern,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get occurrences => $composableBuilder(
    column: $table.occurrences,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get flagged => $composableBuilder(
    column: $table.flagged,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FoodMemoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodMemoriesTable> {
  $$FoodMemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodName => $composableBuilder(
    column: $table.foodName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reactionPattern => $composableBuilder(
    column: $table.reactionPattern,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get occurrences => $composableBuilder(
    column: $table.occurrences,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get flagged => $composableBuilder(
    column: $table.flagged,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodMemoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodMemoriesTable> {
  $$FoodMemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get foodName =>
      $composableBuilder(column: $table.foodName, builder: (column) => column);

  GeneratedColumn<String> get reactionPattern => $composableBuilder(
    column: $table.reactionPattern,
    builder: (column) => column,
  );

  GeneratedColumn<int> get occurrences => $composableBuilder(
    column: $table.occurrences,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<bool> get flagged =>
      $composableBuilder(column: $table.flagged, builder: (column) => column);
}

class $$FoodMemoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodMemoriesTable,
          FoodMemory,
          $$FoodMemoriesTableFilterComposer,
          $$FoodMemoriesTableOrderingComposer,
          $$FoodMemoriesTableAnnotationComposer,
          $$FoodMemoriesTableCreateCompanionBuilder,
          $$FoodMemoriesTableUpdateCompanionBuilder,
          (
            FoodMemory,
            BaseReferences<_$AppDatabase, $FoodMemoriesTable, FoodMemory>,
          ),
          FoodMemory,
          PrefetchHooks Function()
        > {
  $$FoodMemoriesTableTableManager(_$AppDatabase db, $FoodMemoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodMemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodMemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodMemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> foodName = const Value.absent(),
                Value<String?> reactionPattern = const Value.absent(),
                Value<int> occurrences = const Value.absent(),
                Value<DateTime> lastSeen = const Value.absent(),
                Value<bool> flagged = const Value.absent(),
              }) => FoodMemoriesCompanion(
                id: id,
                foodName: foodName,
                reactionPattern: reactionPattern,
                occurrences: occurrences,
                lastSeen: lastSeen,
                flagged: flagged,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String foodName,
                Value<String?> reactionPattern = const Value.absent(),
                Value<int> occurrences = const Value.absent(),
                required DateTime lastSeen,
                Value<bool> flagged = const Value.absent(),
              }) => FoodMemoriesCompanion.insert(
                id: id,
                foodName: foodName,
                reactionPattern: reactionPattern,
                occurrences: occurrences,
                lastSeen: lastSeen,
                flagged: flagged,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FoodMemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodMemoriesTable,
      FoodMemory,
      $$FoodMemoriesTableFilterComposer,
      $$FoodMemoriesTableOrderingComposer,
      $$FoodMemoriesTableAnnotationComposer,
      $$FoodMemoriesTableCreateCompanionBuilder,
      $$FoodMemoriesTableUpdateCompanionBuilder,
      (
        FoodMemory,
        BaseReferences<_$AppDatabase, $FoodMemoriesTable, FoodMemory>,
      ),
      FoodMemory,
      PrefetchHooks Function()
    >;
typedef $$MedicationsTableCreateCompanionBuilder =
    MedicationsCompanion Function({
      Value<int> id,
      required DateTime date,
      required String time,
      required String name,
      Value<double?> dose,
      Value<String?> unit,
      Value<String?> route,
      Value<int?> checkinDelayMinutes,
      Value<String?> rawInput,
      Value<String?> notes,
      Value<Uint8List?> imageData,
      required DateTime createdAt,
    });
typedef $$MedicationsTableUpdateCompanionBuilder =
    MedicationsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> time,
      Value<String> name,
      Value<double?> dose,
      Value<String?> unit,
      Value<String?> route,
      Value<int?> checkinDelayMinutes,
      Value<String?> rawInput,
      Value<String?> notes,
      Value<Uint8List?> imageData,
      Value<DateTime> createdAt,
    });

class $$MedicationsTableFilterComposer
    extends Composer<_$AppDatabase, $MedicationsTable> {
  $$MedicationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get dose => $composableBuilder(
    column: $table.dose,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkinDelayMinutes => $composableBuilder(
    column: $table.checkinDelayMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawInput => $composableBuilder(
    column: $table.rawInput,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get imageData => $composableBuilder(
    column: $table.imageData,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MedicationsTableOrderingComposer
    extends Composer<_$AppDatabase, $MedicationsTable> {
  $$MedicationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get dose => $composableBuilder(
    column: $table.dose,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get route => $composableBuilder(
    column: $table.route,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkinDelayMinutes => $composableBuilder(
    column: $table.checkinDelayMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawInput => $composableBuilder(
    column: $table.rawInput,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get imageData => $composableBuilder(
    column: $table.imageData,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MedicationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MedicationsTable> {
  $$MedicationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get dose =>
      $composableBuilder(column: $table.dose, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get route =>
      $composableBuilder(column: $table.route, builder: (column) => column);

  GeneratedColumn<int> get checkinDelayMinutes => $composableBuilder(
    column: $table.checkinDelayMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawInput =>
      $composableBuilder(column: $table.rawInput, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<Uint8List> get imageData =>
      $composableBuilder(column: $table.imageData, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$MedicationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MedicationsTable,
          Medication,
          $$MedicationsTableFilterComposer,
          $$MedicationsTableOrderingComposer,
          $$MedicationsTableAnnotationComposer,
          $$MedicationsTableCreateCompanionBuilder,
          $$MedicationsTableUpdateCompanionBuilder,
          (
            Medication,
            BaseReferences<_$AppDatabase, $MedicationsTable, Medication>,
          ),
          Medication,
          PrefetchHooks Function()
        > {
  $$MedicationsTableTableManager(_$AppDatabase db, $MedicationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MedicationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MedicationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MedicationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> time = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> dose = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> route = const Value.absent(),
                Value<int?> checkinDelayMinutes = const Value.absent(),
                Value<String?> rawInput = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<Uint8List?> imageData = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => MedicationsCompanion(
                id: id,
                date: date,
                time: time,
                name: name,
                dose: dose,
                unit: unit,
                route: route,
                checkinDelayMinutes: checkinDelayMinutes,
                rawInput: rawInput,
                notes: notes,
                imageData: imageData,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required String time,
                required String name,
                Value<double?> dose = const Value.absent(),
                Value<String?> unit = const Value.absent(),
                Value<String?> route = const Value.absent(),
                Value<int?> checkinDelayMinutes = const Value.absent(),
                Value<String?> rawInput = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<Uint8List?> imageData = const Value.absent(),
                required DateTime createdAt,
              }) => MedicationsCompanion.insert(
                id: id,
                date: date,
                time: time,
                name: name,
                dose: dose,
                unit: unit,
                route: route,
                checkinDelayMinutes: checkinDelayMinutes,
                rawInput: rawInput,
                notes: notes,
                imageData: imageData,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MedicationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MedicationsTable,
      Medication,
      $$MedicationsTableFilterComposer,
      $$MedicationsTableOrderingComposer,
      $$MedicationsTableAnnotationComposer,
      $$MedicationsTableCreateCompanionBuilder,
      $$MedicationsTableUpdateCompanionBuilder,
      (
        Medication,
        BaseReferences<_$AppDatabase, $MedicationsTable, Medication>,
      ),
      Medication,
      PrefetchHooks Function()
    >;
typedef $$MealFingerprintsTableCreateCompanionBuilder =
    MealFingerprintsCompanion Function({
      Value<int> id,
      required int mealId,
      required String date,
      Value<String?> mealType,
      required String foodsSummary,
      Value<int?> totalCals,
      Value<double?> totalProtein,
      required int createdAt,
    });
typedef $$MealFingerprintsTableUpdateCompanionBuilder =
    MealFingerprintsCompanion Function({
      Value<int> id,
      Value<int> mealId,
      Value<String> date,
      Value<String?> mealType,
      Value<String> foodsSummary,
      Value<int?> totalCals,
      Value<double?> totalProtein,
      Value<int> createdAt,
    });

final class $$MealFingerprintsTableReferences
    extends
        BaseReferences<_$AppDatabase, $MealFingerprintsTable, MealFingerprint> {
  $$MealFingerprintsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $MealsTable _mealIdTable(_$AppDatabase db) => db.meals.createAlias(
    $_aliasNameGenerator(db.mealFingerprints.mealId, db.meals.id),
  );

  $$MealsTableProcessedTableManager get mealId {
    final $_column = $_itemColumn<int>('meal_id')!;

    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MealFingerprintsTableFilterComposer
    extends Composer<_$AppDatabase, $MealFingerprintsTable> {
  $$MealFingerprintsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get foodsSummary => $composableBuilder(
    column: $table.foodsSummary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCals => $composableBuilder(
    column: $table.totalCals,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalProtein => $composableBuilder(
    column: $table.totalProtein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MealsTableFilterComposer get mealId {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealFingerprintsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealFingerprintsTable> {
  $$MealFingerprintsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mealType => $composableBuilder(
    column: $table.mealType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get foodsSummary => $composableBuilder(
    column: $table.foodsSummary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCals => $composableBuilder(
    column: $table.totalCals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalProtein => $composableBuilder(
    column: $table.totalProtein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealsTableOrderingComposer get mealId {
    final $$MealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableOrderingComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealFingerprintsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealFingerprintsTable> {
  $$MealFingerprintsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get mealType =>
      $composableBuilder(column: $table.mealType, builder: (column) => column);

  GeneratedColumn<String> get foodsSummary => $composableBuilder(
    column: $table.foodsSummary,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCals =>
      $composableBuilder(column: $table.totalCals, builder: (column) => column);

  GeneratedColumn<double> get totalProtein => $composableBuilder(
    column: $table.totalProtein,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$MealsTableAnnotationComposer get mealId {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealFingerprintsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealFingerprintsTable,
          MealFingerprint,
          $$MealFingerprintsTableFilterComposer,
          $$MealFingerprintsTableOrderingComposer,
          $$MealFingerprintsTableAnnotationComposer,
          $$MealFingerprintsTableCreateCompanionBuilder,
          $$MealFingerprintsTableUpdateCompanionBuilder,
          (MealFingerprint, $$MealFingerprintsTableReferences),
          MealFingerprint,
          PrefetchHooks Function({bool mealId})
        > {
  $$MealFingerprintsTableTableManager(
    _$AppDatabase db,
    $MealFingerprintsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealFingerprintsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealFingerprintsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealFingerprintsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> mealId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<String?> mealType = const Value.absent(),
                Value<String> foodsSummary = const Value.absent(),
                Value<int?> totalCals = const Value.absent(),
                Value<double?> totalProtein = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
              }) => MealFingerprintsCompanion(
                id: id,
                mealId: mealId,
                date: date,
                mealType: mealType,
                foodsSummary: foodsSummary,
                totalCals: totalCals,
                totalProtein: totalProtein,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int mealId,
                required String date,
                Value<String?> mealType = const Value.absent(),
                required String foodsSummary,
                Value<int?> totalCals = const Value.absent(),
                Value<double?> totalProtein = const Value.absent(),
                required int createdAt,
              }) => MealFingerprintsCompanion.insert(
                id: id,
                mealId: mealId,
                date: date,
                mealType: mealType,
                foodsSummary: foodsSummary,
                totalCals: totalCals,
                totalProtein: totalProtein,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MealFingerprintsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mealId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mealId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mealId,
                                referencedTable:
                                    $$MealFingerprintsTableReferences
                                        ._mealIdTable(db),
                                referencedColumn:
                                    $$MealFingerprintsTableReferences
                                        ._mealIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MealFingerprintsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealFingerprintsTable,
      MealFingerprint,
      $$MealFingerprintsTableFilterComposer,
      $$MealFingerprintsTableOrderingComposer,
      $$MealFingerprintsTableAnnotationComposer,
      $$MealFingerprintsTableCreateCompanionBuilder,
      $$MealFingerprintsTableUpdateCompanionBuilder,
      (MealFingerprint, $$MealFingerprintsTableReferences),
      MealFingerprint,
      PrefetchHooks Function({bool mealId})
    >;
typedef $$WaterLogsTableCreateCompanionBuilder =
    WaterLogsCompanion Function({
      Value<int> id,
      required DateTime date,
      required String time,
      required int amountMl,
      Value<String?> notes,
      required DateTime createdAt,
    });
typedef $$WaterLogsTableUpdateCompanionBuilder =
    WaterLogsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> time,
      Value<int> amountMl,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

class $$WaterLogsTableFilterComposer
    extends Composer<_$AppDatabase, $WaterLogsTable> {
  $$WaterLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMl => $composableBuilder(
    column: $table.amountMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WaterLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $WaterLogsTable> {
  $$WaterLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMl => $composableBuilder(
    column: $table.amountMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WaterLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WaterLogsTable> {
  $$WaterLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<int> get amountMl =>
      $composableBuilder(column: $table.amountMl, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WaterLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WaterLogsTable,
          WaterLog,
          $$WaterLogsTableFilterComposer,
          $$WaterLogsTableOrderingComposer,
          $$WaterLogsTableAnnotationComposer,
          $$WaterLogsTableCreateCompanionBuilder,
          $$WaterLogsTableUpdateCompanionBuilder,
          (WaterLog, BaseReferences<_$AppDatabase, $WaterLogsTable, WaterLog>),
          WaterLog,
          PrefetchHooks Function()
        > {
  $$WaterLogsTableTableManager(_$AppDatabase db, $WaterLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WaterLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WaterLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WaterLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> time = const Value.absent(),
                Value<int> amountMl = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WaterLogsCompanion(
                id: id,
                date: date,
                time: time,
                amountMl: amountMl,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required String time,
                required int amountMl,
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
              }) => WaterLogsCompanion.insert(
                id: id,
                date: date,
                time: time,
                amountMl: amountMl,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WaterLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WaterLogsTable,
      WaterLog,
      $$WaterLogsTableFilterComposer,
      $$WaterLogsTableOrderingComposer,
      $$WaterLogsTableAnnotationComposer,
      $$WaterLogsTableCreateCompanionBuilder,
      $$WaterLogsTableUpdateCompanionBuilder,
      (WaterLog, BaseReferences<_$AppDatabase, $WaterLogsTable, WaterLog>),
      WaterLog,
      PrefetchHooks Function()
    >;
typedef $$WeightLogsTableCreateCompanionBuilder =
    WeightLogsCompanion Function({
      Value<int> id,
      required DateTime date,
      required String time,
      required double weightValue,
      required String unit,
      Value<String?> notes,
      required DateTime createdAt,
    });
typedef $$WeightLogsTableUpdateCompanionBuilder =
    WeightLogsCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<String> time,
      Value<double> weightValue,
      Value<String> unit,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

class $$WeightLogsTableFilterComposer
    extends Composer<_$AppDatabase, $WeightLogsTable> {
  $$WeightLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weightValue => $composableBuilder(
    column: $table.weightValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeightLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeightLogsTable> {
  $$WeightLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get time => $composableBuilder(
    column: $table.time,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weightValue => $composableBuilder(
    column: $table.weightValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeightLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeightLogsTable> {
  $$WeightLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get time =>
      $composableBuilder(column: $table.time, builder: (column) => column);

  GeneratedColumn<double> get weightValue => $composableBuilder(
    column: $table.weightValue,
    builder: (column) => column,
  );

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$WeightLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeightLogsTable,
          WeightLog,
          $$WeightLogsTableFilterComposer,
          $$WeightLogsTableOrderingComposer,
          $$WeightLogsTableAnnotationComposer,
          $$WeightLogsTableCreateCompanionBuilder,
          $$WeightLogsTableUpdateCompanionBuilder,
          (
            WeightLog,
            BaseReferences<_$AppDatabase, $WeightLogsTable, WeightLog>,
          ),
          WeightLog,
          PrefetchHooks Function()
        > {
  $$WeightLogsTableTableManager(_$AppDatabase db, $WeightLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeightLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeightLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeightLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> time = const Value.absent(),
                Value<double> weightValue = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => WeightLogsCompanion(
                id: id,
                date: date,
                time: time,
                weightValue: weightValue,
                unit: unit,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required String time,
                required double weightValue,
                required String unit,
                Value<String?> notes = const Value.absent(),
                required DateTime createdAt,
              }) => WeightLogsCompanion.insert(
                id: id,
                date: date,
                time: time,
                weightValue: weightValue,
                unit: unit,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeightLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeightLogsTable,
      WeightLog,
      $$WeightLogsTableFilterComposer,
      $$WeightLogsTableOrderingComposer,
      $$WeightLogsTableAnnotationComposer,
      $$WeightLogsTableCreateCompanionBuilder,
      $$WeightLogsTableUpdateCompanionBuilder,
      (WeightLog, BaseReferences<_$AppDatabase, $WeightLogsTable, WeightLog>),
      WeightLog,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db, _db.meals);
  $$FoodItemsTableTableManager get foodItems =>
      $$FoodItemsTableTableManager(_db, _db.foodItems);
  $$IngredientsTableTableManager get ingredients =>
      $$IngredientsTableTableManager(_db, _db.ingredients);
  $$ReactionLogsTableTableManager get reactionLogs =>
      $$ReactionLogsTableTableManager(_db, _db.reactionLogs);
  $$FoodMemoriesTableTableManager get foodMemories =>
      $$FoodMemoriesTableTableManager(_db, _db.foodMemories);
  $$MedicationsTableTableManager get medications =>
      $$MedicationsTableTableManager(_db, _db.medications);
  $$MealFingerprintsTableTableManager get mealFingerprints =>
      $$MealFingerprintsTableTableManager(_db, _db.mealFingerprints);
  $$WaterLogsTableTableManager get waterLogs =>
      $$WaterLogsTableTableManager(_db, _db.waterLogs);
  $$WeightLogsTableTableManager get weightLogs =>
      $$WeightLogsTableTableManager(_db, _db.weightLogs);
}
