# ompkmn

Web institucional de la **Organización Mundial Pokémon (OMP)** con información de estados/regiones, funciones principales, detalle del sistema **PISA** y la nueva plataforma **idPKMN**.

## Ejecutar en local

```bash
python3 -m http.server 4173
```

Abrir: `http://localhost:4173`

## Base de datos (Supabase)

El esquema SQL para la plataforma idPKMN está en:

- `supabase/schema.sql`

Incluye tablas para perfiles de entrenadores, logros estilo red social, eventos oficiales, autorizaciones PISA y políticas RLS.
