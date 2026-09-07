/**
 * HospitalsPage — Manage hospital records: add, verify, delete.
 * Direct Firestore writes (hospitals/{id} is admin-write-only per rules).
 */

import { useState } from 'react';
import { useHospitals, useAdminActions } from '../hooks/useFirebaseData';
import { Plus, CheckCircle, XCircle, Building2 } from 'lucide-react';
import { Card } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

interface HospitalFormData {
  name: string;
  address: string;
  city: string;
  state: string;
  contact_phone: string;
  contact_email: string;
  lat: string;
  lng: string;
}

const EMPTY_FORM: HospitalFormData = {
  name: '', address: '', city: '', state: '',
  contact_phone: '', contact_email: '', lat: '', lng: '',
};

export default function HospitalsPage() {
  const { hospitals, loading } = useHospitals();
  const { actionLoading, actionError, createHospital, toggleHospitalVerified, deleteHospital } = useAdminActions();
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState<HospitalFormData>(EMPTY_FORM);
  const [formError, setFormError] = useState('');

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    setFormError('');
    try {
      await createHospital({
        ...form,
        lat: form.lat ? parseFloat(form.lat) : undefined,
        lng: form.lng ? parseFloat(form.lng) : undefined,
      });
      setForm(EMPTY_FORM);
      setShowForm(false);
    } catch (err: unknown) {
      setFormError(err instanceof Error ? err.message : 'Failed to create hospital');
    }
  }

  async function handleDelete(hospitalId: string, name: string) {
    if (!confirm(`Delete "${name}"? This cannot be undone.`)) return;
    await deleteHospital(hospitalId, name);
  }

  return (
    <div className="p-6 space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-xl font-semibold">Hospitals</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            {loading ? '…' : `${hospitals.length} hospitals · ${hospitals.filter(h => h.verified).length} verified`}
          </p>
        </div>
        <Button onClick={() => setShowForm(!showForm)}>
          <Plus className="w-4 h-4" /> Add Hospital
        </Button>
      </div>

      {actionError && (
        <div className="bg-destructive/10 border border-destructive/30 rounded-lg px-4 py-3 text-destructive text-sm">{actionError}</div>
      )}

      {showForm && (
        <Card className="p-5">
          <h2 className="text-sm font-semibold mb-4">Add New Hospital</h2>
          <form onSubmit={handleCreate} className="grid grid-cols-2 gap-4">
            {[
              { field: 'name', label: 'Hospital Name', required: true, span: 2 },
              { field: 'address', label: 'Address', required: true, span: 2 },
              { field: 'city', label: 'City', span: 1 },
              { field: 'state', label: 'State', span: 1 },
              { field: 'contact_phone', label: 'Phone', required: true, span: 1 },
              { field: 'contact_email', label: 'Email', span: 1 },
              { field: 'lat', label: 'Latitude', span: 1 },
              { field: 'lng', label: 'Longitude', span: 1 },
            ].map(({ field, label, required, span }) => (
              <div key={field} className={span === 2 ? 'col-span-2' : ''}>
                <label className="block text-xs font-medium text-muted-foreground mb-1">{label}{required && ' *'}</label>
                <input
                  type="text"
                  value={form[field as keyof HospitalFormData]}
                  onChange={(e) => setForm({ ...form, [field]: e.target.value })}
                  required={required}
                  className="w-full px-3 py-2 rounded-lg bg-background border border-input text-sm placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-ring"
                />
              </div>
            ))}
            {formError && <div className="col-span-2 text-destructive text-sm">{formError}</div>}
            <div className="col-span-2 flex gap-2 justify-end">
              <Button type="button" variant="secondary" onClick={() => setShowForm(false)}>Cancel</Button>
              <Button type="submit" disabled={actionLoading}>
                {actionLoading ? 'Creating…' : 'Create Hospital'}
              </Button>
            </div>
          </form>
        </Card>
      )}

      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {[...Array(6)].map((_, i) => (
            <div key={i} className="h-36 bg-card rounded-lg border border-border animate-pulse" />
          ))}
        </div>
      ) : hospitals.length === 0 ? (
        <Card className="p-12 text-center">
          <Building2 className="w-10 h-10 text-muted-foreground/40 mx-auto mb-3" />
          <p className="text-muted-foreground text-sm">No hospitals added yet.</p>
        </Card>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {hospitals.map((hospital) => (
            <Card key={hospital.id} className="p-4">
              <div className="flex items-start justify-between mb-2">
                <div>
                  <p className="text-sm font-semibold">{hospital.name}</p>
                  <p className="text-xs text-muted-foreground mt-0.5">{hospital.address}</p>
                  {hospital.city && <p className="text-xs text-muted-foreground/70">{hospital.city}, {hospital.state}</p>}
                </div>
                {hospital.verified
                  ? <CheckCircle className="w-4 h-4 text-emerald-500 flex-shrink-0" />
                  : <XCircle className="w-4 h-4 text-muted-foreground/40 flex-shrink-0" />
                }
              </div>
              <p className="text-xs text-muted-foreground mb-3">{hospital.contact_phone}</p>
              <div className="flex gap-2">
                <Button
                  size="sm"
                  variant="secondary"
                  className="flex-1"
                  disabled={actionLoading}
                  onClick={() => toggleHospitalVerified(hospital.id, !hospital.verified, hospital.name)}
                >
                  {hospital.verified ? 'Unverify' : 'Verify'}
                </Button>
                <Button
                  size="sm"
                  variant="destructive"
                  disabled={actionLoading}
                  onClick={() => handleDelete(hospital.id, hospital.name)}
                >
                  Delete
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}
