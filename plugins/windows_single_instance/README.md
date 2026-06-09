# Windows Single Instance

Restrict a Windows app to only be able to open one instance at a time.

## Installing

1. Add `WidgetsFlutterBinding.ensureInitialized();` to the start of your apps `main` function.
1. Add the `async` modifier to your apps `main` function.
1. Add a call to `WindowsSingleInstance.ensureSingleInstance()`, passing the apps startup args, a custom app string unique to your app (a-z, 0-9, \_ and - only), and an optional callback function.

## Example

```
void main(List<String> args) async {
    WidgetsFlutterBinding.ensureInitialized();
    await WindowsSingleInstance.ensureSingleInstance(
        args,
        "custom_identifier",
        onSecondWindow: (args) {
            print(args);
        });
    runApp(const MyApp());
}
```
