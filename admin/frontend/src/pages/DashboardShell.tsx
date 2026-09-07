/**
 * DashboardShell — Sidebar + topbar layout wrapper for all admin pages.
 * Theme-aware (light/dark via CSS variable tokens) — no hardcoded colors.
 */

import { Routes, Route, NavLink, useLocation } from 'react-router-dom';
import { useState } from 'react';
import {
  LayoutDashboard, Users, Droplets, Building2, Map as MapIcon,
  History, BarChart3, Bell, Shield, LogOut, PanelLeftClose, PanelLeft,
} from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { cn } from '../lib/utils';
import { Avatar, AvatarFallback } from '@/components/ui/avatar';
import {
  DropdownMenu, DropdownMenuContent, DropdownMenuItem,
  DropdownMenuLabel, DropdownMenuSeparator, DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';

import DashboardHome from './DashboardHome';
import MapPage from './MapPage';
import DonorsPage from './DonorsPage';
import RequestsPage from './RequestsPage';
import HospitalsPage from './HospitalsPage';
import DonationHistoryPage from './DonationHistoryPage';
import AnalyticsPage from './AnalyticsPage';
import AuditLogPage from './AuditLogPage';
import BroadcastPage from './BroadcastPage';

const navGroups = [
  {
    label: 'Overview',
    items: [
      { to: '/', label: 'Dashboard', icon: LayoutDashboard, end: true },
      { to: '/map', label: 'Map', icon: MapIcon, end: false },
    ],
  },
  {
    label: 'Manage',
    items: [
      { to: '/donors', label: 'Donors', icon: Users, end: false },
      { to: '/requests', label: 'Requests', icon: Droplets, end: false },
      { to: '/hospitals', label: 'Hospitals', icon: Building2, end: false },
    ],
  },
  {
    label: 'Insights',
    items: [
      { to: '/history', label: 'Donations', icon: History, end: false },
      { to: '/analytics', label: 'Analytics', icon: BarChart3, end: false },
    ],
  },
  {
    label: 'Admin',
    items: [
      { to: '/broadcast', label: 'Broadcast', icon: Bell, end: false },
      { to: '/audit', label: 'Audit Log', icon: Shield, end: false },
    ],
  },
];

const PAGE_TITLES: Record<string, string> = {
  '/': 'Dashboard',
  '/map': 'Map',
  '/donors': 'Donors',
  '/requests': 'Blood Requests',
  '/hospitals': 'Hospitals',
  '/history': 'Donation History',
  '/analytics': 'Analytics',
  '/broadcast': 'Broadcast',
  '/audit': 'Audit Log',
};

export default function DashboardShell() {
  const { currentUser, logout } = useAuth();
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const { pathname } = useLocation();
  const title = PAGE_TITLES[pathname] || 'Dashboard';

  const initial = currentUser?.email?.[0]?.toUpperCase() || 'A';

  return (
    <div className="flex h-screen bg-background text-foreground overflow-hidden">
      {/* ── Sidebar ─────────────────────────────────────────────────── */}
      <aside
        className={cn(
          'flex flex-col bg-card border-r border-border transition-all duration-300',
          sidebarOpen ? 'w-60' : 'w-16'
        )}
      >
        <div className="flex items-center gap-3 px-4 py-5 border-b border-border">
          <div className="flex-shrink-0 w-8 h-8 rounded-lg bg-gradient-to-br from-primary to-primary/70 flex items-center justify-center shadow-sm">
            <Droplets className="w-4 h-4 text-primary-foreground" />
          </div>
          {sidebarOpen && (
            <div className="min-w-0">
              <p className="text-sm font-semibold leading-none truncate">Rakta Bandhan</p>
              <p className="text-xs text-muted-foreground mt-0.5">Admin Panel</p>
            </div>
          )}
        </div>

        <nav className="flex-1 px-2 py-4 overflow-y-auto">
          {navGroups.map((group) => (
            <div key={group.label} className="mb-4 last:mb-0">
              {sidebarOpen && (
                <p className="px-3 mb-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground/60">
                  {group.label}
                </p>
              )}
              <div className="space-y-0.5">
                {group.items.map(({ to, label, icon: Icon, end }) => (
                  <NavLink
                    key={to}
                    to={to}
                    end={end}
                    className={({ isActive }) =>
                      cn(
                        'flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm font-medium transition-colors',
                        isActive
                          ? 'bg-primary/10 text-primary'
                          : 'text-muted-foreground hover:text-foreground hover:bg-accent'
                      )
                    }
                  >
                    <Icon className="w-4 h-4 flex-shrink-0" />
                    {sidebarOpen && <span className="truncate">{label}</span>}
                  </NavLink>
                ))}
              </div>
            </div>
          ))}
        </nav>

        <div className="border-t border-border px-3 py-3">
          <button
            onClick={() => setSidebarOpen((v) => !v)}
            className={cn(
              'flex items-center gap-2 w-full px-3 py-2 rounded-lg text-sm text-muted-foreground hover:text-foreground hover:bg-accent transition-colors',
              !sidebarOpen && 'justify-center'
            )}
          >
            {sidebarOpen ? <PanelLeftClose className="w-4 h-4 flex-shrink-0" /> : <PanelLeft className="w-4 h-4 flex-shrink-0" />}
            {sidebarOpen && <span>Collapse</span>}
          </button>
        </div>
      </aside>

      {/* ── Main Content ─────────────────────────────────────────────── */}
      <div className="flex-1 flex flex-col min-w-0 overflow-hidden">
        <header className="flex items-center gap-4 px-6 py-4 border-b border-border bg-card/50 backdrop-blur-sm">
          <h1 className="text-base font-semibold">{title}</h1>
          <div className="flex-1" />
          <DropdownMenu>
            <DropdownMenuTrigger className="outline-none">
              <Avatar className="h-8 w-8 cursor-pointer">
                <AvatarFallback className="bg-primary/10 text-primary text-xs font-semibold">
                  {initial}
                </AvatarFallback>
              </Avatar>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-56">
              <DropdownMenuLabel>
                <p className="text-sm font-medium">Admin</p>
                <p className="text-xs text-muted-foreground font-normal truncate">{currentUser?.email}</p>
              </DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={logout} className="text-red-600 focus:text-red-600">
                <LogOut className="w-4 h-4" />
                Sign out
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </header>

        <main className="flex-1 overflow-y-auto">
          <Routes>
            <Route path="/"           element={<DashboardHome />} />
            <Route path="/map"        element={<MapPage />} />
            <Route path="/donors"     element={<DonorsPage />} />
            <Route path="/requests"   element={<RequestsPage />} />
            <Route path="/hospitals"  element={<HospitalsPage />} />
            <Route path="/history"    element={<DonationHistoryPage />} />
            <Route path="/analytics"  element={<AnalyticsPage />} />
            <Route path="/broadcast"  element={<BroadcastPage />} />
            <Route path="/audit"      element={<AuditLogPage />} />
          </Routes>
        </main>
      </div>
    </div>
  );
}
