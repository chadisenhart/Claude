import { LightningElement, track } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import CHARTJS   from '@salesforce/resourceUrl/chartjs';
import LEAFLET   from '@salesforce/resourceUrl/leafletjs';
import getDashboardData from '@salesforce/apex/FDRDashboardController.getDashboardData';

// ISO country name → [lat, lng]
const COUNTRY_COORDS = {
    'Russia':               [55.75,  37.61],
    'United States':        [37.09, -95.71],
    'Honduras':             [15.20, -86.24],
    'Egypt':                [26.82,  30.80],
    'West Bank':            [31.95,  35.23],
    'United Arab Emirates': [23.42,  53.85],
    'UAE':                  [23.42,  53.85],
    'Iran':                 [32.43,  53.69],
    'Israel':               [31.05,  34.85],
    'Kenya':                [-0.02,  37.91],
    'Colombia':             [4.57,  -74.30],
    'Nigeria':              [9.08,    8.68],
    'Niger':                [17.61,   8.08],
    'Ukraine':              [48.38,  31.17],
    'Turkey':               [38.96,  35.24],
    'Syria':                [34.80,  38.99],
    'Haiti':                [18.97, -72.29],
    'Guatemala':            [15.78, -90.23],
    'El Salvador':          [13.79, -88.90],
    'Nicaragua':            [12.87, -85.21],
    'Peru':                 [-9.19, -75.02],
    'Brazil':               [-14.24,-51.93],
    'Philippines':          [12.88, 121.77],
    'Indonesia':            [-0.79, 113.92],
    'India':                [20.59,  78.96],
    'Nepal':                [28.39,  84.12],
    'Pakistan':             [30.38,  69.35],
    'Afghanistan':          [33.94,  67.71],
    'Ethiopia':             [9.14,   40.49],
    'South Sudan':          [6.88,   31.57],
    'Somalia':              [5.15,   46.20],
    'Democratic Republic of the Congo': [-4.04, 21.76],
    'Mozambique':           [-18.66, 35.53],
    'Malawi':               [-13.25, 34.30],
    'Zimbabwe':             [-19.02, 29.15],
    'Venezuela':            [6.42,  -66.59],
};

const PIE_COLORS = [
    '#FF6B35', '#FFA500', '#CC0000', '#8B4513',
    '#4169E1', '#FF69B4', '#20B2AA', '#9370DB',
    '#DAA520', '#32CD32',
];

const LEVEL_COLORS = {
    Red:    '#CC0000',
    Orange: '#E05C14',
    Yellow: '#F5A623',
    Blue:   '#4169E1',
};

export default class FdrOperationsDashboard extends LightningElement {

    // ── Filters ──────────────────────────────────────────────────────────
    @track startDate = `${new Date().getFullYear()}-01-01`;
    @track endDate   = `${new Date().getFullYear()}-12-31`;
    @track selectedGlobalArea = 'All';
    @track selectedRegion     = 'All';

    // ── State ─────────────────────────────────────────────────────────────
    @track isLoading  = true;
    @track hasData    = false;
    @track hasError   = false;
    @track error      = '';

    // ── Filter option lists ───────────────────────────────────────────────
    @track globalAreaOptions = [{ label: 'All', value: 'All' }];
    @track regionOptions     = [{ label: 'All', value: 'All' }];

    // ── Dashboard data ────────────────────────────────────────────────────
    _data = null;

    // ── Internal flags ───────────────────────────────────────────────────
    _libsLoaded  = false;
    _pieChart    = null;
    _barChart    = null;
    _leafletMap  = null;
    _mapMarkers  = [];

    // ─────────────────────────────────────────────────────────────────────
    connectedCallback() {
        this._loadLibraries();
        this._fetchData();
    }

    async _loadLibraries() {
        try {
            await Promise.all([
                loadScript(this, CHARTJS),
                loadScript(this, LEAFLET + '/leaflet.js'),
                loadStyle(this, LEAFLET + '/leaflet.css'),
            ]);
            this._libsLoaded = true;
            if (this._data) this._renderVisuals();
        } catch (err) {
            this.hasError = true;
            this.error =
                'Could not load Chart.js / Leaflet.js. ' +
                'Upload them as Static Resources named "chartjs" and "leafletjs". ' +
                'See DEPLOY.md for instructions. (' + err.message + ')';
        }
    }

    async _fetchData() {
        this.isLoading = true;
        this.hasData   = false;
        try {
            const result = await getDashboardData({
                startDate:  this.startDate,
                endDate:    this.endDate,
                globalArea: this.selectedGlobalArea,
                region:     this.selectedRegion,
                country:    'All',
            });
            this._data   = result;
            this.hasData = true;
            this.hasError = false;

            if (result.globalAreaOptions) {
                this.globalAreaOptions = result.globalAreaOptions.map(v => ({ label: v, value: v }));
            }
            if (result.regionOptions) {
                this.regionOptions = result.regionOptions.map(v => ({ label: v, value: v }));
            }

            if (this._libsLoaded) this._renderVisuals();
        } catch (err) {
            this.hasError = true;
            this.error    = 'Error loading data: ' + (err.body?.message || err.message || String(err));
        } finally {
            this.isLoading = false;
        }
    }

    _renderVisuals() {
        // Defer until after LWC renders the template
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this._renderPieChart();
            this._renderBarChart();
            this._renderMap();
        }, 50);
    }

    // ── Pie Chart ─────────────────────────────────────────────────────────
    _renderPieChart() {
        const canvas = this.template.querySelector('.fdr-pie-canvas');
        if (!canvas || !this._data?.byDisasterType?.length) return;

        const labels = this._data.byDisasterType.map(d => d.label);
        const values = this._data.byDisasterType.map(d => d.value);

        if (this._pieChart) {
            this._pieChart.data.labels                = labels;
            this._pieChart.data.datasets[0].data      = values;
            this._pieChart.update();
            return;
        }

        // eslint-disable-next-line no-undef
        this._pieChart = new Chart(canvas.getContext('2d'), {
            type: 'pie',
            data: {
                labels,
                datasets: [{
                    data: values,
                    backgroundColor: PIE_COLORS,
                    borderWidth: 2,
                    borderColor: '#ffffff',
                }],
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'right',
                        labels: { font: { size: 11 }, boxWidth: 12, padding: 8 },
                    },
                    tooltip: {
                        callbacks: {
                            label: ctx => {
                                const total = ctx.dataset.data.reduce((a, b) => a + b, 0);
                                const pct   = ((ctx.raw / total) * 100).toFixed(1);
                                return `${ctx.label}: ${ctx.raw} (${pct}%)`;
                            },
                        },
                    },
                },
            },
        });
    }

    // ── Bar Chart ─────────────────────────────────────────────────────────
    _renderBarChart() {
        const canvas = this.template.querySelector('.fdr-bar-canvas');
        if (!canvas || !this._data?.byMonth?.length) return;

        const labels = this._data.byMonth.map(d => d.label);
        const values = this._data.byMonth.map(d => d.value);
        const maxVal = Math.max(...values);

        if (this._barChart) {
            this._barChart.data.labels           = labels;
            this._barChart.data.datasets[0].data = values;
            this._barChart.update();
            return;
        }

        // eslint-disable-next-line no-undef
        this._barChart = new Chart(canvas.getContext('2d'), {
            type: 'bar',
            data: {
                labels,
                datasets: [{
                    label: 'Responses',
                    data: values,
                    backgroundColor: '#e05c14',
                    borderRadius: 3,
                }],
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: { legend: { display: false } },
                scales: {
                    y: {
                        beginAtZero: true,
                        max: maxVal + 2,
                        ticks: { stepSize: 1, precision: 0 },
                        grid: { color: '#e5e5e5' },
                    },
                    x: { grid: { display: false } },
                },
            },
        });
    }

    // ── Leaflet Map ───────────────────────────────────────────────────────
    _renderMap() {
        const mapEl = this.template.querySelector('.fdr-leaflet-map');
        if (!mapEl || !window.L) return;

        // Destroy previous map instance before re-initializing
        if (this._leafletMap) {
            this._leafletMap.remove();
            this._leafletMap = null;
        }

        this._leafletMap = window.L.map(mapEl, {
            center: [20, 10],
            zoom: 2,
            minZoom: 1,
            scrollWheelZoom: false,
            zoomControl: true,
        });

        window.L.tileLayer(
            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            {
                attribution: '© OpenStreetMap contributors',
                maxZoom: 18,
            }
        ).addTo(this._leafletMap);

        if (!this._data?.responses?.length) return;

        const seenCountries = new Set();
        this._data.responses.forEach(r => {
            const name = r.Country__c;
            if (!name || seenCountries.has(name)) return;
            seenCountries.add(name);

            const coords = COUNTRY_COORDS[name];
            if (!coords) return;

            const color  = LEVEL_COLORS[r.Level__c] || '#e05c14';
            const marker = window.L.circleMarker(coords, {
                radius:      10,
                fillColor:   color,
                color:       '#ffffff',
                weight:      2,
                opacity:     1,
                fillOpacity: 0.85,
            });

            marker.bindPopup(
                `<b>${name}</b><br/>` +
                `Status: <b>${r.Response_Status__c || ''}</b><br/>` +
                `Level: <b>${r.Level__c || ''}</b><br/>` +
                `Type: ${r.Disaster_Type__c || ''}`
            );
            marker.addTo(this._leafletMap);
        });
    }

    // ── Template getters ─────────────────────────────────────────────────
    get totalResponses()     { return this._data?.totalResponses     ?? 0; }
    get activeResponses()    { return this._data?.activeResponses    ?? 0; }
    get planningResponses()  { return this._data?.planningResponses  ?? 0; }
    get countriesServed()    { return this._data?.countriesServed    ?? 0; }
    get usDomesticResponses(){ return this._data?.usDomesticResponses ?? 0; }
    get grantsDispersed()    { return this._data?.grantsDispersed    ?? 0; }

    get grantFundsFormatted() {
        const v = this._data?.grantFundsProvided ?? 0;
        if (v >= 1000000) return '$' + (v / 1000000).toFixed(1) + 'M';
        if (v >= 1000)    return '$' + (v / 1000).toFixed(1) + 'K';
        return '$' + Number(v).toFixed(0);
    }

    get responseRows() {
        if (!this._data?.responses) return [];
        return this._data.responses.map(r => ({
            Id:               r.Id,
            Response_Name__c: r.Response_Name__c || r.Name,
            Country__c:       r.Country__c,
            FMI_Region__c:    r.FMI_Region__c,
            Disaster_Type__c: r.Disaster_Type__c,
            Level__c:         r.Level__c,
            Response_Status__c: r.Response_Status__c,
            formattedDate:    this._formatDate(r.Response_Date__c),
            levelClass:       'fdr-badge fdr-level-' + (r.Level__c  || 'default').toLowerCase(),
            statusClass:      'fdr-badge fdr-status-' + (r.Response_Status__c || 'default').toLowerCase().replace(/\s+/g, '-'),
        }));
    }

    _formatDate(dateStr) {
        if (!dateStr) return '';
        const [y, m, d] = dateStr.split('-');
        return `${m}/${d}/${y}`;
    }

    // ── Filter handlers ──────────────────────────────────────────────────
    handleGlobalAreaChange(event) {
        this.selectedGlobalArea = event.detail.value;
        this._resetCharts();
        this._fetchData();
    }

    handleRegionChange(event) {
        this.selectedRegion = event.detail.value;
        this._resetCharts();
        this._fetchData();
    }

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        this._resetCharts();
        this._fetchData();
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        this._resetCharts();
        this._fetchData();
    }

    _resetCharts() {
        if (this._pieChart) { this._pieChart.destroy(); this._pieChart = null; }
        if (this._barChart) { this._barChart.destroy(); this._barChart = null; }
    }

    openOpsForm() {
        // Replace with your actual FDR Ops Form URL
        window.open('https://thefoursquarechurch2.lightning.force.com', '_blank');
    }
}
