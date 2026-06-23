# Smarthome DSL

## Compile

```cmd
mvn compile
```

## Generate Python

```cmd
scripts\generate.cmd test\idea\parking_controller.smrt target\generated\ParkingController.py
```

The first run may take longer because Maven and Rascal generate parser/compiler artifacts.
