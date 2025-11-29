# `pm` - Project Management Backend

Este proyecto implementa un backend de gestión de proyectos en el Internet Computer, escrito en Motoko.

## Resumen de la Arquitectura

El backend está construido sobre un actor principal (`pm`) que orquesta la lógica de negocio y utiliza canisters `Bucket` que se crean dinámicamente para el almacenamiento de archivos.

### Canisters

El proyecto se compone de los siguientes canisters definidos en `dfx.json`:

- **`pm`**: El canister principal del backend. Gestiona la lógica para usuarios, workspaces, proyectos y comentarios.
- **`bucket`**: Una clase de canister que se utiliza para almacenar archivos (assets). El sistema crea nuevas instancias de este canister según sea necesario para escalar el almacenamiento.
- **`frontend`**: Un canister de tipo `assets` para servir la interfaz de usuario.

### Flujo de Almacenamiento y Comentarios

Una característica clave de la arquitectura es cómo maneja los archivos adjuntos en los comentarios para ser eficiente y escalable:

1.  **Comentarios de solo texto**: Se añaden de forma síncrona directamente al proyecto dentro del canister `pm`.
2.  **Comentarios con Archivos Adjuntos**:
    - El canister `pm` recibe la petición y, en lugar de procesar el archivo directamente, solicita un canister de almacenamiento al módulo `FileStorage`.
    - Si no hay un canister `Bucket` con espacio suficiente, el sistema crea e instala uno nuevo de forma programática y asíncrona.
    - El canister `pm` responde al cliente con el `canister_id` del `Bucket` donde debe subir el archivo.
    - El cliente sube el archivo directamente al `Bucket` correspondiente.
    - Una vez completada la subida, el `Bucket` notifica al canister `pm` (mediante un callback a `onFileLoaded`), que entonces crea la referencia al archivo y finaliza la creación del comentario.

Este enfoque desacoplado evita que el canister principal se bloquee con subidas de archivos pesados y permite que el almacenamiento crezca de manera elástica.

## Desarrollo Local

Para levantar el proyecto en tu entorno local, sigue estos pasos:

```bash
# Inicia la réplica local en segundo plano
dfx start --background

# Despliega los canisters en la réplica
dfx deploy
```

Una vez completado, la aplicación estará disponible en `http://localhost:4943?canisterId={asset_canister_id}`.

## Pruebas

El proyecto incluye un script de pruebas de integración que simula un flujo de uso completo. Este script:
1. Crea identidades de prueba.
2. Despliega el canister `pm`.
3. Crea usuarios, workspaces y proyectos utilizando las identidades de prueba.

Para ejecutar las pruebas, simplemente ejecuta el siguiente comando desde la raíz del proyecto:

```bash
./scripts/pm_test.sh
```

El script se encargará de iniciar y limpiar el entorno de `dfx` necesario para la prueba.