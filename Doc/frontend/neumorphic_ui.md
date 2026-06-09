# Neumorphism in UI Design (Diseño Neumórfico)

Para el proyecto **MusicRoom**, se utilizo un diseño **Neumorfismo (Soft UI)**.
Este estilo utiliza luces y sombras planas para hacer que las tarjetas y botones parezcan "hundidos" en la superficie del fondo de la aplicacion.

## Paleta de Colores y Tokens

El Neumorfismo requiere que el color de fondo y el color de las tarjetas/componentes sea exactamente el mismo. El relieve se logra exclusivamente usando dos sombras: una sombra clara (luz) y una sombra oscura (sombra).

Definimos esta paleta en [app_theme.dart](file:///Users/diegoluna/Documents/42course/music-room/frontend/music_room_app/lib/core/theme/app_theme.dart):

- **Light Theme Background**: `#E0EAE5` (Un verde/grisáceo suave).
- **Dark Theme Background**: `#121A14` (Un verde oscuro/bosque muy profundo).

## Tokens de Diseño (ThemeExtension)

Para no ensuciar la UI con BoxShadows codificadas a mano (hardcoded), extendimos el sistema de temas nativo de Flutter usando `ThemeExtension<AppDesignTokens>`. Esto nos permite inyectar los tokens neumorficos directamente en el tema global.

### Tokens Registrados:

- `blurAmount`: Radio de desenfoque de las sombras (16.0 en luz, 20.0 en oscuro).
- `cardRadius`: El redondeado de las esquinas (`AppDimens.radiusApple` = 22.0).
- `neumorphicShadow`: La combinacion de dos sombras para botones elevados (offset negativo blanco para luz, offset positivo oscuro para sombra).
- `neumorphicPressedShadow`: Las sombras interiores para simular un boton presionado (hundido).

## Cómo Consumir Neumorfismo en tus Widgets

Para aplicar el diseño neumorfico sobre un `Container`, recupera la extension del tema actual utilizando el `BuildContext`:

```dart
@override
Widget build(BuildContext context) {
	// * Obtener los tokens de diseño neumorfico del tema actual
	final designTokens = Theme.of(context).extension<AppDesignTokens>()!;

	return Container(
		decoration: BoxDecoration(
			color: Theme.of(context).scaffoldBackgroundColor, // ! Debe ser el mismo color de fondo
			borderRadius: designTokens.cardRadius,
			boxShadow: designTokens.neumorphicShadow, // * Relieve elevado
		),
		child: const Padding(
			padding: EdgeInsets.all(16.0),
			child: Text('Tarjeta Neumorfica'),
		),
	);
}
```

**Important:** Para simular un estado "presionado" (hundido) en botones neumorficos, intercambia la sombra activa a `designTokens.neumorphicPressedShadow` basandote en un booleano de estado local del widget.
