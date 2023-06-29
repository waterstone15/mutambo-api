# Data Model Versioning

'00000.00000.00000' == 'Major.Minor.Patch'

## Major

The change requires a full, multi-step data migration to avoid downtime.

## Minor

The change requires one or more updates to the API and or the Web App, but does note require a full migration to avoid downtime.

## Patch

All less significant changes.


## Migration Steps

1. Update API to write twice (keep writing old model, and write new model)
2. Migrate old-model-only records to new model
3. Update API and Web to read only new model 
4. Remove old-models
