import { useEffect, useRef, useState } from 'react'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'

const pin = L.divIcon({
  className: 'public-map-marker',
  html: '<span aria-hidden="true"></span>',
  iconSize: [26, 26],
  iconAnchor: [13, 26],
})

export default function LocationMap({ coordinates, onChange, disabled }) {
  const container = useRef(null)
  const map = useRef(null)
  const marker = useRef(null)
  const accuracy = useRef(null)
  const change = useRef(onChange)
  const [tileError, setTileError] = useState(false)
  useEffect(() => {
    change.current = onChange
  }, [onChange])
  useEffect(() => {
    const instance = L.map(container.current, {
      scrollWheelZoom: false,
    }).setView([-25.3, -57.63], 12)
    map.current = instance
    L.tileLayer('https://tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution:
        '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 19,
    })
      .on('tileerror', () => setTileError(true))
      .addTo(instance)
    return () => {
      instance.remove()
      map.current = null
      marker.current = null
      accuracy.current = null
    }
  }, [])
  useEffect(() => {
    const instance = map.current
    const select = (e) =>
      change.current({
        latitude: Number(e.latlng.lat.toFixed(7)),
        longitude: Number(e.latlng.lng.toFixed(7)),
        accuracy: null,
        source: 'manual',
        captured_at: new Date().toISOString(),
      })
    if (!disabled) instance.on('click', select)
    if (coordinates) {
      const point = [coordinates.latitude, coordinates.longitude]
      if (!marker.current) {
        marker.current = L.marker(point, {
          icon: pin,
          draggable: !disabled,
          title: 'Ubicación elegida. Arrastra para ajustar.',
          alt: 'Ubicación de la emergencia',
        }).addTo(instance)
        marker.current.on('dragend', () =>
          select({ latlng: marker.current.getLatLng() }),
        )
      }
      marker.current.setLatLng(point)
      if (disabled) marker.current.dragging.disable()
      else marker.current.dragging.enable()
      instance.setView(point, Math.max(instance.getZoom(), 15))
    } else if (marker.current) {
      marker.current.remove()
      marker.current = null
    }
    if (accuracy.current) {
      accuracy.current.remove()
      accuracy.current = null
    }
    if (coordinates?.accuracy > 0)
      accuracy.current = L.circle(
        [coordinates.latitude, coordinates.longitude],
        {
          radius: coordinates.accuracy,
          color: '#538775',
          weight: 1,
          fillOpacity: 0.08,
        },
      ).addTo(instance)
    return () => instance.off('click', select)
  }, [coordinates, disabled])
  return (
    <div>
      <div
        ref={container}
        className="public-leaflet-map"
        role="region"
        aria-label="Mapa de ubicación: pulsa para colocar el marcador o introduce las coordenadas debajo"
      />
      {tileError && (
        <p className="public-warning" role="status">
          No se pudo cargar parte del mapa. Puedes introducir coordenadas o
          describir el lugar; el fondo del mapa necesita internet.
        </p>
      )}
    </div>
  )
}
