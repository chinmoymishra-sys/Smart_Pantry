import 'package:sqflite/sqflite.dart';

import '../../core/enums/pantry_enums.dart';
import '../../core/utils/units.dart';
import '../../features/meals/models/recipe.dart';

/// Local recipe catalog seeded on first launch. Recipes are app content, not
/// inventory. "Spinach chickpea skillet" is transcribed from the design; the
/// methods of the other three recipes were authored to match the design's
/// card data and are flagged for content review in docs/IMPLEMENTATION_NOTES.md.
abstract final class RecipeSeed {
  static const _img = 'assets/images';

  static RecipeIngredient _ing(
    String recipeId,
    int order,
    String name,
    List<String> keys,
    double qty,
    PantryUnit unit, {
    bool required = true,
    String? display,
    String? prep,
  }) =>
      RecipeIngredient(
        id: '$recipeId-i$order',
        recipeId: recipeId,
        name: name,
        matchKeys: keys,
        quantity: qty,
        unit: unit,
        isRequired: required,
        displayOrder: order,
        displayQuantity: display,
        preparation: prep,
      );

  static RecipeStep _step(
    String recipeId,
    int n,
    String title,
    String instruction, {
    String? headline,
    int? minutes,
    String? timerNote,
  }) =>
      RecipeStep(
        id: '$recipeId-s$n',
        recipeId: recipeId,
        stepNumber: n,
        title: title,
        instruction: instruction,
        headline: headline,
        durationSeconds: minutes == null ? null : minutes * 60,
        timerNote: timerNote,
      );

  static List<Recipe> get recipes {
    const oats = 'berry-yogurt-oats';
    const skillet = 'spinach-chickpea-skillet';
    const toast = 'paneer-tomato-toast';
    const rice = 'peas-onion-rice';
    return [
      Recipe(
        id: oats,
        name: 'Berry & yogurt oats',
        description: 'A warm bowl with a cool, creamy finish.',
        summary: 'A quick, cosy breakfast for one.',
        mealType: MealType.breakfast,
        prepMinutes: 3,
        cookMinutes: 5,
        difficulty: Difficulty.easy,
        servings: 1,
        cuisines: const ['Comfort food'],
        dietTags: const ['Vegetarian'],
        equipment: 'Small saucepan, wooden spoon and a bowl.',
        imagePath: '$_img/berry_yogurt_oats.jpg',
        thumbnailPath: '$_img/thumb_berry_yogurt_oats.jpg',
        optionalNote: 'Drizzle a little over the top if you have it.',
        ingredients: [
          _ing(oats, 1, 'Oats', const ['oats', 'rolled oats'], 50, PantryUnit.g),
          _ing(oats, 2, 'Blueberries', const ['blueberries', 'blueberry'], 50,
              PantryUnit.g),
          _ing(oats, 3, 'Yogurt', const ['yogurt', 'plain yogurt'], 100,
              PantryUnit.g),
          _ing(oats, 4, 'Honey', const ['honey'], 1, PantryUnit.servings,
              required: false, display: 'Honey'),
        ],
        steps: [
          _step(oats, 1, 'Simmer the oats',
              'Put 50 g oats in a small saucepan with enough water to cover. Simmer for about 5 minutes, stirring, until creamy.',
              headline: 'Put 50 g oats in a small saucepan with enough water to cover.',
              minutes: 5,
              timerNote: 'Timer is a guide. Stir so the oats don’t catch.'),
          _step(oats, 2, 'Top and serve',
              'Spoon the oats into a bowl. Top with 100 g yogurt and 50 g blueberries. Add honey if you have it.',
              headline: 'Spoon the oats into a bowl.'),
        ],
      ),
      Recipe(
        id: skillet,
        name: 'Spinach chickpea skillet',
        description: 'Tender greens, tomatoes and golden chickpeas.',
        summary: 'A quick, comforting lunch for two.',
        mealType: MealType.lunch,
        prepMinutes: 5,
        cookMinutes: 12,
        difficulty: Difficulty.easy,
        servings: 2,
        cuisines: const ['Mediterranean', 'One-pot'],
        dietTags: const ['Vegetarian', 'Vegan', 'Dairy-free'],
        equipment:
            'Frying pan, knife, chopping board, colander and wooden spoon.',
        imagePath: '$_img/spinach_chickpea_skillet.jpg',
        thumbnailPath: '$_img/thumb_spinach_chickpea_skillet.jpg',
        optionalNote: 'Skip it or add a squeeze to finish.',
        ingredients: [
          _ing(skillet, 1, 'Spinach', const ['spinach'], 100, PantryUnit.g,
              prep: 'washed and chopped'),
          _ing(skillet, 2, 'Tomatoes', const ['tomatoes', 'tomato'], 2,
              PantryUnit.pieces,
              prep: 'chopped'),
          _ing(skillet, 3, 'Chickpeas', const ['chickpeas', 'chickpea'], 1,
              PantryUnit.tins,
              prep: '240 g drained'),
          _ing(skillet, 4, 'Olive oil', const ['olive oil'], 15, PantryUnit.ml,
              prep: '1 tablespoon'),
          _ing(skillet, 5, 'Lemon', const ['lemon', 'lemons'], 0.5,
              PantryUnit.pieces,
              required: false, display: '½ lemon'),
        ],
        steps: [
          _step(skillet, 1, 'Prep the ingredients',
              'Wash 100 g spinach and 2 tomatoes. Roughly chop both. Drain and rinse 1 tin of chickpeas (240 g drained). Set out 15 ml olive oil.',
              headline: 'Wash 100 g spinach and 2 tomatoes.',
              minutes: 5,
              timerNote: 'Timer is a guide. Take the time you need.'),
          _step(skillet, 2, 'Soften the tomatoes',
              'Warm 15 ml olive oil in a frying pan over medium heat. Add 2 chopped tomatoes. Cook for about 6 minutes, stirring, until softened. Lower the heat if they catch.',
              headline: 'Warm 15 ml olive oil in a frying pan over medium heat.',
              minutes: 6,
              timerNote: 'Timer is a guide. Check the tomatoes as they cook.'),
          _step(skillet, 3, 'Warm the chickpeas',
              'Stir in the drained chickpeas. Cook for about 4 minutes, stirring occasionally, until warmed through. If the pan is dry, add a small splash of water.',
              headline: 'Stir in the drained chickpeas.',
              minutes: 4,
              timerNote: 'Timer is a guide. Stir now and then.'),
          _step(skillet, 4, 'Wilt, then serve',
              'Fold in 100 g spinach and stir for about 2 minutes, until wilted. Divide between 2 bowls. Finish with optional lemon if you have it. Adjust the timing to your pan.',
              headline: 'Fold in 100 g spinach and stir for about 2 minutes, until wilted.',
              minutes: 2,
              timerNote: 'Timer is a guide. Stop once the spinach wilts.'),
        ],
      ),
      Recipe(
        id: toast,
        name: 'Paneer tomato toast',
        description: 'A crisp, savory afternoon pick-me-up.',
        summary: 'A crisp, savory snack for two.',
        mealType: MealType.snacks,
        prepMinutes: 5,
        cookMinutes: 5,
        difficulty: Difficulty.easy,
        servings: 2,
        cuisines: const ['Indian-inspired'],
        dietTags: const ['Vegetarian'],
        equipment: 'Frying pan, toaster or grill, knife and chopping board.',
        imagePath: '$_img/paneer_tomato_toast.jpg',
        thumbnailPath: '$_img/thumb_paneer_tomato_toast.jpg',
        ingredients: [
          _ing(toast, 1, 'Paneer', const ['paneer'], 100, PantryUnit.g,
              prep: 'cubed'),
          _ing(toast, 2, 'Tomato', const ['tomatoes', 'tomato'], 1,
              PantryUnit.pieces,
              prep: 'sliced'),
          _ing(toast, 3, 'Bread', const ['bread'], 2, PantryUnit.slices),
        ],
        steps: [
          _step(toast, 1, 'Prep and toast',
              'Cube 100 g paneer and slice 1 tomato. Toast 2 slices of bread.',
              headline: 'Cube 100 g paneer and slice 1 tomato.',
              minutes: 3),
          _step(toast, 2, 'Brown the paneer',
              'Cook the paneer in a dry or lightly oiled frying pan for about 2 minutes, turning, until golden at the edges.',
              headline: 'Cook the paneer in a frying pan until golden at the edges.',
              minutes: 2,
              timerNote: 'Timer is a guide. Turn the paneer as it browns.'),
          _step(toast, 3, 'Assemble',
              'Layer the tomato slices on the toast and top with the paneer. Serve straight away.',
              headline: 'Layer the tomato slices on the toast and top with the paneer.'),
        ],
      ),
      Recipe(
        id: rice,
        name: 'Peas & onion rice',
        description: 'A simple one-pot dinner for a quiet evening.',
        summary: 'A simple one-pot dinner for two.',
        mealType: MealType.dinner,
        prepMinutes: 5,
        cookMinutes: 20,
        difficulty: Difficulty.easy,
        servings: 2,
        cuisines: const ['One-pot', 'Indian-inspired'],
        dietTags: const ['Vegetarian', 'Vegan', 'Dairy-free'],
        equipment: 'Saucepan with a lid, knife, chopping board and wooden spoon.',
        imagePath: '$_img/peas_onion_rice.jpg',
        thumbnailPath: '$_img/thumb_peas_onion_rice.jpg',
        ingredients: [
          _ing(rice, 1, 'Rice', const ['rice'], 150, PantryUnit.g, prep: 'rinsed'),
          _ing(rice, 2, 'Green peas', const ['green peas', 'peas'], 100,
              PantryUnit.g),
          _ing(rice, 3, 'Olive oil', const ['olive oil'], 10, PantryUnit.ml),
          _ing(rice, 4, 'Onion', const ['onion', 'onions'], 1, PantryUnit.pieces,
              prep: 'finely chopped'),
        ],
        steps: [
          _step(rice, 1, 'Soften the onion',
              'Rinse 150 g rice. Warm 10 ml olive oil in a saucepan over medium heat and cook 1 finely chopped onion for about 5 minutes, until soft.',
              headline: 'Rinse 150 g rice and finely chop 1 onion.',
              minutes: 5,
              timerNote: 'Timer is a guide. Lower the heat if the onion browns.'),
          _step(rice, 2, 'Simmer the rice',
              'Stir in the rice, add 300 ml water and bring to a simmer. Cover and cook gently for about 12 minutes.',
              headline: 'Stir in the rice and add 300 ml water.',
              minutes: 12,
              timerNote: 'Timer is a guide. Keep the lid on.'),
          _step(rice, 3, 'Add the peas',
              'Scatter 100 g green peas over the rice, cover again and cook for about 3 minutes, until the rice is tender and the peas are hot. Fluff with a fork and serve.',
              headline: 'Scatter 100 g green peas over the rice and cover again.',
              minutes: 3,
              timerNote: 'Timer is a guide. Check the rice is tender.'),
        ],
      ),
    ];
  }

  static Future<void> insertAll(DatabaseExecutor db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    for (final r in recipes) {
      await db.insert('recipes', {...r.toRow(), 'created_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace);
      for (final i in r.ingredients) {
        await db.insert('recipe_ingredients', i.toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final s in r.steps) {
        await db.insert('recipe_steps', s.toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
  }
}
