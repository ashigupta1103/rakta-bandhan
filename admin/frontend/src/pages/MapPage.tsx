/**
 * MapPage — live geographic view of donors, open requests, and hospitals.
 * Real Firestore data via the same hooks the other pages use (admin reads
 * the private /donors collection directly, same as DonorsPage) — no demo
 * pins. Free basemap tiles (CARTO via MapLibre), no API key needed.
 */

import { useMemo } from 'react';
import { Droplets, Building2, Users } from 'lucide-react';
import { Map, MapMarker, MarkerContent, MarkerTooltip } from '@/components/ui/mapcn-marker-content';
import { Card } from '@/components/ui/card';
import { useDonors, useRequests, useHospitals } from '../hooks/useFirebaseData';

// Chennai — Rotary Club of Madras Cosmos's home city, opens here regardless
// of where donor/request data happens to be.
const DEFAULT_CENTER: [number, number] = [80.2707, 13.0827];

function Dot({ className }: { className: string }) {
  return <div className={`h-4 w-4 rounded-full border-2 border-white shadow-lg ${className}`} />;
}

export default function MapPage() {
  const { donors, loading: donorsLoading } = useDonors();
  const { requests, loading: requestsLoading } = useRequests('open');
  const { hospitals, loading: hospitalsLoading } = useHospitals();

  const availableDonors = useMemo(
    () => donors.filter((d) => d.is_available && d.is_verified && !d.is_banned && d.lat && d.lng),
    [donors]
  );
  const openRequests = useMemo(() => requests.filter((r) => r.lat && r.lng), [requests]);
  const verifiedHospitals = useMemo(() => hospitals.filter((h) => h.lat && h.lng), [hospitals]);

  const loading = donorsLoading || requestsLoading || hospitalsLoading;

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold">Map</h1>
        <p className="text-sm text-muted-foreground mt-0.5">
          {loading
            ? 'Loading…'
            : `${availableDonors.length} available donor(s) · ${openRequests.length} open request(s) · ${verifiedHospitals.length} hospital(s)`}
        </p>
      </div>

      <Card className="relative h-[calc(100vh-220px)] min-h-[420px] overflow-hidden p-0">
        <Map theme="light" center={DEFAULT_CENTER} zoom={11} loading={loading} className="rounded-[inherit]">
          {availableDonors.map((donor) => (
            <MapMarker key={`donor-${donor.id}`} longitude={donor.lng} latitude={donor.lat}>
              <MarkerContent>
                <Dot className="bg-emerald-500" />
              </MarkerContent>
              <MarkerTooltip>
                {donor.name} · {donor.blood_group} · available
              </MarkerTooltip>
            </MapMarker>
          ))}

          {openRequests.map((req) => (
            <MapMarker key={`request-${req.id}`} longitude={req.lng} latitude={req.lat}>
              <MarkerContent>
                <Dot className="bg-primary" />
              </MarkerContent>
              <MarkerTooltip>
                {req.blood_group} needed · {req.urgency} · {req.units_needed} unit(s)
              </MarkerTooltip>
            </MapMarker>
          ))}

          {verifiedHospitals.map((hospital) => (
            <MapMarker key={`hospital-${hospital.id}`} longitude={hospital.lng!} latitude={hospital.lat!}>
              <MarkerContent>
                <Dot className="bg-blue-500" />
              </MarkerContent>
              <MarkerTooltip>{hospital.name}</MarkerTooltip>
            </MapMarker>
          ))}
        </Map>

        {/* Legend */}
        <div className="absolute left-3 top-3 z-10 rounded-lg border border-border bg-card/95 px-3 py-2.5 shadow-warm backdrop-blur-sm">
          <div className="space-y-1.5 text-xs">
            <div className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full bg-emerald-500" />
              <Users className="h-3 w-3 text-muted-foreground" />
              <span className="text-muted-foreground">Available donors</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full bg-primary" />
              <Droplets className="h-3 w-3 text-muted-foreground" />
              <span className="text-muted-foreground">Open requests</span>
            </div>
            <div className="flex items-center gap-2">
              <span className="h-2.5 w-2.5 rounded-full bg-blue-500" />
              <Building2 className="h-3 w-3 text-muted-foreground" />
              <span className="text-muted-foreground">Hospitals</span>
            </div>
          </div>
        </div>
      </Card>
    </div>
  );
}
