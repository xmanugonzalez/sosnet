export const EMERGENCY_TYPES = [
  'Inundación',
  'Asistencia médica',
  'Evacuación',
  'Incendio',
  'Suministros',
  'Otra',
]

export function emptyRequest() {
  return {
    name: '',
    contact: '',
    type: '',
    people: '1',
    description: '',
    location: '',
    references: '',
    coordinates: null,
  }
}

export function validCoordinates(latitude, longitude) {
  return (
    Number.isFinite(latitude) &&
    latitude >= -90 &&
    latitude <= 90 &&
    Number.isFinite(longitude) &&
    longitude >= -180 &&
    longitude <= 180
  )
}

export function validateRequest(values) {
  const errors = {}
  if (values.name.trim().length < 2)
    errors.name = 'Escribe el nombre de la persona que solicita ayuda.'
  if (
    !/^\+?[\d\s()-]{6,25}$/.test(values.contact.trim()) ||
    values.contact.replace(/\D/g, '').length < 6
  )
    errors.contact =
      'Escribe un número de contacto válido, con al menos 6 dígitos.'
  if (!EMERGENCY_TYPES.includes(values.type))
    errors.type = 'Selecciona el tipo de emergencia.'
  if (
    !Number.isInteger(Number(values.people)) ||
    Number(values.people) < 1 ||
    Number(values.people) > 1000
  )
    errors.people = 'Indica entre 1 y 1000 personas, sin decimales.'
  if (values.description.trim().length < 10)
    errors.description = 'Describe lo que ocurre con al menos 10 caracteres.'
  if (!values.location.trim() && !values.coordinates)
    errors.location = 'Describe dónde estás o agrega tus coordenadas.'
  if (
    values.coordinates &&
    !validCoordinates(values.coordinates.latitude, values.coordinates.longitude)
  )
    errors.location =
      'Revisa las coordenadas: latitud entre −90 y 90 y longitud entre −180 y 180.'
  return errors
}

// Contrato provisional. El adaptador del servicio es el único punto de traducción a Flask.
export function toPayload(values, clientRequestId) {
  return {
    schema_version: 1,
    client_request_id: clientRequestId,
    reporter: { name: values.name.trim(), contact: values.contact.trim() },
    emergency: {
      type: values.type,
      affected_people: Number(values.people),
      description: values.description.trim(),
    },
    location: {
      description: values.location.trim(),
      references: values.references.trim(),
      coordinates: values.coordinates,
    },
  }
}
