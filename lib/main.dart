import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shopping_list/controllers/auth_controller.dart';
import 'package:shopping_list/controllers/item_list_controller.dart';
import 'package:shopping_list/models/item_model.dart';
import 'package:shopping_list/repository/custom_exception.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    //FirebaseCrashlytics.instance.crash();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Flutter firebase riverpod",
      theme: ThemeData.dark(),
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final authControllerState = useProvider(authControllerProvider);
    final itemListFilter = useProvider(itemListFilterProvider);
    final isObtainedFilter = itemListFilter.state == ItemListFilter.obtained;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        leading: authControllerState != null
            ? IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () =>
                    context.read(authControllerProvider.notifier).signOut(),
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(isObtainedFilter
                ? Icons.check_circle
                : Icons.check_circle_outline),
            onPressed: () => itemListFilter.state =
                isObtainedFilter ? ItemListFilter.all : ItemListFilter.obtained,
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddItemDialog.show(context, Item.empty()),
        child: const Icon(Icons.add),
      ),
      body: ProviderListener(
        onChange: (
          BuildContext context,
          StateController<CustomException?> customException,
        ) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(customException.state!.message!),
            ),
          );
        },
        provider: itemListExceptionProvider,
        child: ItemList(),
      ),
    );
  }
}

final currentItem = ScopedProvider<Item>((_) => throw UnimplementedError());

class ItemList extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final itemListState = useProvider(itemListControllerProvider);
    final filteredItemList = useProvider(filteredItemListProvider);
    return itemListState.when(
      data: (items) => items.isEmpty
          ? const Center(
              child: Text(
                'Tap + to add an item',
                style: TextStyle(fontSize: 20.0),
              ),
            )
          : ListView.builder(
              itemCount: filteredItemList.length,
              itemBuilder: (context, index) {
                final item = filteredItemList[index];
                return ProviderScope(
                    overrides: [currentItem.overrideWithValue(item)],
                    child: ItemTile());
              },
            ),
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => ItemListError(
        message:
            error is CustomException ? error.message! : "Something went wrong!",
      ),
    );
  }
}

class ItemTile extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final item = useProvider(currentItem);
    return ListTile(
      key: ValueKey(item.id),
      title: Text(item.name),
      trailing: Checkbox(
        value: item.obtained,
        onChanged: (val) =>
            context.read(itemListControllerProvider.notifier).updateItem(
                  updatedItem: item.copyWith(obtained: !item.obtained),
                ),
      ),
      onTap: () => AddItemDialog.show(context, item),
      onLongPress: () => context
          .read(itemListControllerProvider.notifier)
          .deleteItem(itemId: item.id!),
    );
  }
}

class ItemListError extends StatelessWidget {
  final String message;
  const ItemListError({required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(fontSize: 20.0),
          ),
          const SizedBox(
            height: 20.0,
          ),
          ElevatedButton(
            onPressed: () => context
                .read(itemListControllerProvider.notifier)
                .retrieveItems(isRefreshing: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class AddItemDialog extends HookWidget {
  static void show(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(item: item),
    );
  }

  final Item item;
  const AddItemDialog({required this.item});

  bool get isUpdating => item.id != null;

  @override
  Widget build(BuildContext context) {
    final textController = useTextEditingController(text: item.name);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Item name'),
            ),
            const SizedBox(
              height: 12.0,
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    primary: isUpdating
                        ? Colors.orange
                        : Theme.of(context).primaryColor),
                onPressed: () {
                  isUpdating
                      ? context
                          .read(itemListControllerProvider.notifier)
                          .updateItem(
                            updatedItem: item.copyWith(
                                name: textController.text.trim(),
                                obtained: item.obtained),
                          )
                      : context
                          .read(itemListControllerProvider.notifier)
                          .addItems(name: textController.text.trim());

                  Navigator.of(context).pop();
                },
                child: Text(isUpdating ? 'Update' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
