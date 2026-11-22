# Estado actual

**Subfase:** 1.3 — Fábrica Blender headless, LODs y anclas de rig  
**Versión:** `v0.1.2`  
**Modelo de la subfase:** MiMo Pro  
**Fecha:** 2026-11-22  
**Estado:** completada y publicada.

## Enlaces

- Web: https://emanuelindustri-source.github.io/ruta-nocturna-1999/
- Repositorio: https://github.com/emanuelindustri-source/ruta-nocturna-1999
- Acciones: https://github.com/emanuelindustri-source/ruta-nocturna-1999/actions

## Validación ejecutada

| Prueba | Resultado |
|---|---|
| Contratos JSON + Schemas | 5 contratos válidos, 0 errores, 1 advertencia de claves de contenido |
| Localización | 11 idiomas, 59 claves, 0 errores; fuentes CJK pendientes de F8.4 |
| Manifiestos de assets | 4 salidas verificadas por hash, LOD0/1/2 decrecientes, 17 anclas |
| Roadmap | 3/45 subfases completadas (6,7%), JSON sincronizado |
| Godot import headless | exit 0; los 4 GLB del bloqueo importan como escena sin errores |
| Smoke test | 118/118 comprobaciones, exit 0 (87 de servicios base + 31 del bloqueo) |
| Blender headless | Blender 4.5.16 LTS; fábrica reproducible con `--factory-startup` |
| Triángulos del bloqueo | LOD0 1.192 · LOD1 440 · LOD2 184 (presupuestos 8.000/4.000/1.500) |
| Referencias | 94 archivos, escaneo rápido sin cambios |
| Health check | 11 OK, 3 advertencias esperadas, 0 errores |

Advertencias conocidas:

- 202 claves de contenido aún no están en el CSV de localización. Se completarán
  en F8.4; la UI base ya está cubierta.
- Las fuentes CJK/cirílicas se empaquetan y validan visualmente en F8.4.
- Las cotas del bloqueo del Esteem (`data/vehicle/blockout_spec.json`) son
  valores de diseño provisionales estimados desde las fotografías; el manual de
  servicio disponible no incluye cotas de carrocería. Verificación obligatoria
  antes de Fase 2/Fase 5.
- El cambio de LOD por distancia y el presupuesto de escena completa se miden en
  Fase 3.5/Fase 10.
- No se probó un cierre nativo real: no hay APK todavía. La prueba Android/ADB
  corresponde a la Fase 1.4.

## Completado

- Fábrica Blender headless: `tools/blender/build_assets.py` invoca Blender 4.5.16
  con `--background --factory-startup` y ejecuta `tools/blender/esteem_blockout.py`,
  un generador paramétrico que lee `data/vehicle/blockout_spec.json`.
- Bloqueo del Esteem (greybox de masas: bajos, capó, cabina, maletero y
  parachoces, más cuatro ruedas) exportado a `assets/generated/vehicle/` con
  LOD0/LOD1/LOD2: 1.192 / 440 / 184 triángulos, estrictamente decrecientes y
  dentro de presupuesto.
- Ancla de rig `esteem_rig_anchor.glb`: armazón `EsteemRigAnchor` →
  `anchor_root` → 16 anclas nombradas (ruedas, asientos, volante, palanca
  automática, freno de mano, cámaras, capó, maletero, espejos y techo) que Godot
  importa como `Skeleton3D` de 17 huesos. Sin piel ni animación todavía.
- Manifiesto reproducible por asset: comando exacto, hashes SHA-256 de script,
  spec y salidas, autor, licencia CC BY-NC-SA 4.0 y fecha UTC.
- `tools/validate_assets.py` valida manifiestos, detecta manifiestos obsoletos,
  comprueba la política de LOD y la coherencia del ancla de rig con el spec;
  integrado en `health_check.py`.
- Escena `scenes/vehicle/EsteemBlockout.tscn` con los tres LODs (solo LOD0
  visible) y el ancla de rig.
- Smoke test ampliado: manifiesto, hashes de las cuatro salidas, triángulos por
  LOD comparados con el manifiesto y existencia de los 17 huesos del ancla.
- Documentación: `docs/architecture/ASSET_FACTORY.md`, sección 11 de
  `DATA_CONTRACTS.md`, cotas provisionales en `ESTEEM_MECHANICAL_NOTES.md` y
  registro de referencias usadas en `REFERENCE_USAGE_LOG.md`.

## Siguiente

Fase **1.4 con DS-S**: CI, test Android/ADB, export Windows/APK, health check
completo, Pages y tag de vertical slice `v0.1.3`.
