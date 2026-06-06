# Documentacion de CI-CD (GitHub Actions)

Sobre la integracion y el despliegue continuo de nuestro projecto (**CI/CD**) configurado con **GitHub Actions**. Tenemos tres flujos de trabajo principales para automatizar las tareas del backend y del frontend.

## 1. Backend CI (backend-ci.yml)

Este flujo se ejecuta cuando hay cambios en el folder del backend o cuando se modifica el archivo de configuracion del workflow. Se activa con pull requests o con push directos a las ramas **main** o **backend**.

### Tareas que ejecuta:

- Checkout del codigo del repositorio.
- Setup del entorno con **Node.js version 24** y cache de dependencias.
- Instalacion limpia de dependencias usando **npm ci**.
- Levantamiento de servicios en contenedores docker integrados:
  - Base de datos **Postgres version 18**.
  - Servicio **Redis version 7**.
- Generacion del cliente de Prisma y despliegue del schema de base de datos ejecutando las migraciones.
- Buidl del projecto para verificar errores de compilacion.
- Ejecucion de pruebas unitarias (**npm test**).
- Ejecucion de pruebas de integracion y e2e (**npm run test:e2e**) contra la base de datos real y **Redis** en Docker.

## 2. Deploy Production (deploy-main.yml)

Este flujo se encarga del despliegue obligatorio del frontend en produccion. Se activa unicamente al hacer push a la rama **main** cuando hay modificaciones en la carpeta del frontend.

### Tareas de construccion y despliegue:

- Setup de Flutter en su canal estable con cache activado.
- Instalacion de dependencias del frontend usando **flutter pub get**.
- Construccion de la version web con flutter build web inyectando la variable de entorno **BACKEND_API_URL** desde los secretos de GitHub para apuntar al backend real.
- Carga del artefacto web generado.
- Despliegue automatico a GitHub Pages usando las credenciales de **github-pages**.

Nota: Las secciones para compilar el APK de Android y el IPA unsigned de iOS estan actualmente comentadas en el archivo para optimizar el consumo de minutos de construccion en GitHub.

## 3. Validate Pull Request (validate-pr.yml)

Este flujo es de caracter obligatorio para validar la integridad del codigo del frontend antes de realizar un merge hacia las ramas **dev** o **main**. Se activa con cualquier creacion o actualizacion de un pull request que altere archivos dentro del folder del frontend.

### Trabajos de validacion:

- **Job de Tests**: Instala dependencias de Flutter y ejecuta todas las pruebas unitarias y de widgets con **flutter test** para asegurar que no hay regresiones.
- **Job de Verify Build**: Compila la aplicacion web para produccion usando **flutter build web** para asegurar que no existan errores de compilacion de Dart o imports rotos. El merge de la pull request queda bloqueado si alguno de estos jobs falla.
