import { LightningElement, track } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import getDashboardData from '@salesforce/apex/MissionsDashboardController.getDashboardData';
import LEAFLET_JS  from '@salesforce/resourceUrl/leafletjs';
import LEAFLET_CSS from '@salesforce/resourceUrl/leafletjs';

const STATUS_COLORS = {
    'Active':           '#27ae60',
    'Home Assignment':  '#f39c12',
    'Candidate':        '#2980b9',
    'On Hold':          '#95a5a6',
};

const STATUS_CLASSES = {
    'Active':           'badge st-active',
    'Home Assignment':  'badge st-home',
    'Candidate':        'badge st-candidate',
    'On Hold':          'badge st-hold',
};

const fmt = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });

export default class MissionsDashboard extends LightningElement {
    @track isLoading  = true;
    @track error      = null;
    @track regionOptions = ['All'];
    @track missionaries  = [];
    @track countries     = [];
    @track stats = { totalMissionaries: 0, activeMissionaries: 0, totalCountries: 0, totalGivingFormatted: '$0' };

    selectedRegion = 'All';
    selectedStatus = 'All';
    searchTerm     = '';
    leafletReady   = false;
    mapInstance    = null;

    connectedCallback() {
        this.fetchData();
    }

    async fetchData() {
        this.isLoading = true;
        try {
            const data = await getDashboardData({
                region:       this.selectedRegion,
                statusFilter: this.selectedStatus,
            });
            this.applyData(data);
            await this.initMap();
        } catch (e) {
            this.error = e;
        } finally {
            this.isLoading = false;
        }
    }

    applyData(data) {
        this.regionOptions = data.regionOptions || ['All'];

        this.missionaries = (data.missionaries || []).map(m => ({
            ...m,
            statusClass:    STATUS_CLASSES[m.status] || 'badge st-hold',
            givingFormatted: m.totalGiving > 0 ? fmt.format(m.totalGiving) : '—',
            recordUrl:      `/lightning/r/Contact/${m.id}/view`,
        }));

        this.countries = data.countries || [];

        this.stats = {
            totalMissionaries:  data.totalMissionaries || 0,
            activeMissionaries: data.activeMissionaries || 0,
            totalCountries:     data.totalCountries || 0,
            totalGivingFormatted: fmt.format(data.totalGiving || 0),
        };
    }

    async initMap() {
        if (!this.leafletReady) {
            await loadStyle(this, LEAFLET_CSS + '/leaflet.css');
            await loadScript(this, LEAFLET_JS  + '/leaflet.js');
            this.leafletReady = true;
        }
        this.renderMap();
    }

    renderMap() {
        // eslint-disable-next-line no-undef
        const L = window.L;
        const container = this.refs.mapContainer;
        if (!container || !L) return;

        if (this.mapInstance) {
            this.mapInstance.remove();
            this.mapInstance = null;
        }

        const map = L.map(container, { zoomControl: true, scrollWheelZoom: false }).setView([20, 10], 2);
        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '© OpenStreetMap contributors',
            maxZoom: 10,
        }).addTo(map);

        this.countries.forEach(c => {
            if (c.latitude == null || c.longitude == null) return;
            const color  = c.activeCount > 0 ? STATUS_COLORS['Active'] : STATUS_COLORS['On Hold'];
            const radius = Math.max(8, Math.min(c.missionaryCount * 5, 30));

            const circle = L.circleMarker([c.latitude, c.longitude], {
                radius,
                fillColor:   color,
                color:       '#fff',
                weight:      2,
                opacity:     1,
                fillOpacity: 0.85,
            }).addTo(map);

            const names = c.missionaryNames.slice(0, 5).join('<br>');
            const more  = c.missionaryNames.length > 5 ? `<br><em>+${c.missionaryNames.length - 5} more</em>` : '';
            circle.bindPopup(
                `<strong>${c.country}</strong><br>` +
                `${c.missionaryCount} missionary(ies) · ${c.activeCount} active<br>` +
                `<small>${names}${more}</small>`
            );
        });

        this.mapInstance = map;
    }

    get filteredMissionaries() {
        const term = this.searchTerm.toLowerCase();
        return this.missionaries.filter(m => {
            if (term && !m.name.toLowerCase().includes(term) && !m.country.toLowerCase().includes(term)) {
                return false;
            }
            return true;
        });
    }

    get filteredCount() { return this.filteredMissionaries.length; }

    get hasActiveFilter() {
        return this.selectedRegion !== 'All' || this.selectedStatus !== 'All' || this.searchTerm.length > 0;
    }

    get errorMessage() {
        return this.error ? (this.error.body ? this.error.body.message : String(this.error)) : '';
    }

    handleRegionChange(event) {
        this.selectedRegion = event.target.value;
        this.fetchData();
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
        this.fetchData();
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }
}
