import { LightningElement, track } from 'lwc';
import getUserProjects from '@salesforce/apex/TimesheetController.getUserProjects';
import getSubmittedTimesheet from '@salesforce/apex/TimesheetController.getSubmittedTimesheet';
import saveTimesheet from '@salesforce/apex/TimesheetController.saveTimesheet';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class WeeklyTimesheet extends LightningElement {
    @track projects = [];
    @track entries = {};
    @track submitted = false;
    currentWeekStart = new Date();

    connectedCallback() {
        this.currentWeekStart = this.getMonday(new Date());
        console.log('currentWeekStart:15=>',this.currentWeekStart);
        this.loadProjects();
        this.checkIfSubmitted();
    }

    get dateRange() {
        const monthFormatter = new Intl.DateTimeFormat('default', { month: 'short' });
        const yearFormatter = new Intl.DateTimeFormat('default', { year: 'numeric' });
    
        const startDate = this.currentWeekStart;
        const endDate = new Date(startDate);
        endDate.setDate(startDate.getDate() + 6);
    
        const startMonth = monthFormatter.format(startDate);
        const endMonth = monthFormatter.format(endDate);
        const year = yearFormatter.format(startDate);
    
        return `${startMonth} ${startDate.getDate()}-${endMonth} ${endDate.getDate()}, ${year}`;
    }

    get weekDates() {
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
        return days.map((label, i) => {
            const d = new Date(this.currentWeekStart);
            d.setDate(d.getDate() + i);
    
            const month = d.toLocaleString('default', { month: 'short' }).toUpperCase();
             // const date = d.toISOString().split('T')[0];
            return { label, date: d.toISOString().split('T')[0], formatDate: `${month} ${d.getDate()}` };
        });
    }

    getMonday(d) {
        const date = new Date(d);
        console.log('date:30=>',date);
        const day = date.getDay();
        console.log('day:32=>',day);
        console.log('date.getDate():33=>',date.getDate());
        const diff = date.getDate() - day + (day === 0 ? -6 : 1);
        return new Date(date.setDate(diff));
    }

    handlePreviousWeek() {
        console.log('inside handlePreviousWeek');
        console.log('this.currentWeekStart:=>',this.currentWeekStart);
        console.log('this.currentWeekStart.getDate():40=>',this.currentWeekStart.getDate());
        this.currentWeekStart.setDate(this.currentWeekStart.getDate() - 7);
        this.currentWeekStart = new Date(this.currentWeekStart);
        this.loadProjects();
        this.checkIfSubmitted();
    }

    handleNextWeek() {
        console.log('inside handleNextWeek');
        console.log('this.currentWeekStart:=51>',this.currentWeekStart);
        console.log('this.currentWeekStart.getDate():52=>',this.currentWeekStart.getDate());
        this.currentWeekStart.setDate(this.currentWeekStart.getDate() + 7);
        this.currentWeekStart = new Date(this.currentWeekStart);
        this.loadProjects();
        this.checkIfSubmitted();
    }

    async loadProjects() {
        try {
            const result = await getUserProjects();
            console.log('result:56=>',result);
            this.projects = result || [];

            this.projects.forEach(p => {
                console.log('p:57=>',p);
                console.log('this.entries:58=>',this.entries);
                
                if (!this.entries[p.Id]) {
                    this.entries[p.Id] = {
                        description: '',
                        ...Object.fromEntries(this.weekDates.map(day => [day.date, 0]))
                    };
                }
            });
            this.entries = { ...this.entries };
            console.log('this.entries:59=>',this.entries);
            
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error loading projects',
                message: error.body?.message || error.message,
                variant: 'error'
            }));
        }
    }

    async checkIfSubmitted() {
        try {
            const start = this.currentWeekStart.toISOString().split('T')[0];
            console.log('start:91=>',start);
            const ts = await getSubmittedTimesheet({ weekStart: start });
            console.log('ts:93=>',ts);
            this.submitted = ts !== null;
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error checking submission status',
                message: error.body?.message || error.message,
                variant: 'error'
            }));
        }
    }

    handleHourChange(event) {
        const pid = event.target.dataset.projectId;
        console.log('pid:106=>',pid);
        const date = event.target.dataset.date;
        console.log('date:107=>',date);
        
        const value = parseFloat(event.target.value) || 0;
        console.log('value:108=>',value);
        console.log('this.entries:109=>',this.entries);
        console.log('this.entries[pid][date]:',this.entries[pid][date]);
        
        if (!this.entries[pid]) {
            this.entries[pid] = { description: '' };
        }

        this.entries[pid][date] = value;
        this.entries = { ...this.entries };
        console.log('this.entries:110=>',this.entries);
        
    }

    handleDescriptionChange(event) {
        const pid = event.target.dataset.projectId;
        console.log(pid);
        console.log('this.entries:114=>',this.entries);
               
        if (!this.entries[pid]) {
            this.entries[pid] = {};
        }
        this.entries[pid].description = event.target.value;
        this.entries = { ...this.entries };
        console.log('this.entries:135=>',this.entries);
    }

    getTotalHoursForProject(projectId) {
        if (!this.entries[projectId]) return 0;
        return this.weekDates.reduce((sum, day) => sum + (this.entries[projectId][day.date] || 0), 0);
    }

    async handleSubmit() {
        if (this.submitted) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Already Submitted',
                message: 'You have already submitted a timesheet for this week.',
                variant: 'info'
            }));
            return;
        }
    
        let hasValidEntry = false;
        console.log('this.entries:426=>', this.entries);
        
        // Create a new object with restructured entries
        const formattedEntries = {};
        
        for (let pid in this.entries) {
            console.log('pid:427=>', pid);
            const projectEntry = this.entries[pid];
            console.log('projectEntry:428=>', projectEntry);
            
            const total = this.getTotalHoursForProject(pid);
            console.log('total:164=>', total);
            
            const desc = projectEntry?.description?.trim();
            console.log('desc:167=>', desc);
            
            if (total > 0 && desc) {
                console.log('inside if:136');
                hasValidEntry = true;
                
                // Create a new entry with hours separated from metadata
                formattedEntries[pid] = {
                    description: desc,
                    hours: {}
                };
                
                // Add all date entries to the hours object
                for (let key in projectEntry) {
                    if (key !== 'description' && projectEntry[key] !== null && projectEntry[key] !== undefined) {
                        formattedEntries[pid].hours[key] = projectEntry[key];
                    }
                }
                
            } else if (total > 0 && !desc) {
                console.log('inside else if:139');
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Missing Description',
                    message: 'Please enter description for projects with hours.',
                    variant: 'warning'
                }));
                return;
            }
        }
    
        if (!hasValidEntry) {
            console.log('inside has valid:150');
            this.dispatchEvent(new ShowToastEvent({
                title: 'Validation Error',
                message: 'Please log hours and enter description for at least one project.',
                variant: 'error'
            }));
            return;
        }
    
        try {
            console.log('formattedEntries:154=>', formattedEntries);
            console.log('this.currentWeekStart:155=>', this.currentWeekStart);
            const weekStartStr = this.currentWeekStart.toISOString().split('T')[0];
            console.log('weekStartStr:156=>', weekStartStr);
            
            await saveTimesheet({
                weekStart: weekStartStr,
                entries: formattedEntries
            });
            console.log('submitted success');
            
            this.submitted = true;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Success',
                message: 'Timesheet submitted successfully!',
                variant: 'success'
            }));
        } catch (err) {
            console.log('error:175=>', err);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: err.body?.message || err.message,
                variant: 'error'
            }));
        }
    }

    get timesheetRows() {
        let rows = [];

        if (!this.projects || !this.weekDates) return [];
        console.log('this.projects:226=>',this.projects);
        
        this.projects.forEach(project => {
            let row = {
                projectId: project.Id,
                projectName: project.Name,
                days: [],
                totalHours: 0,
                description: this.entries[project.Id]?.description || ''
            };

            console.log('this.weekDates:237=>',this.weekDates);
            this.weekDates.forEach(day => {
                const hours = this.entries[project.Id]?.[day.date] || 0;
                console.log('hours:240=>',hours);
                row.days.push({ date: day.date, label: day.label, hours });
                row.totalHours += parseFloat(hours);
            });

            console.log('row:245=>',row);
            rows.push(row);
        });
        console.log('rows:244=>',rows);
        return rows;
    }

    getInputValue(projectId, date) {
        return this.entries[projectId]?.[date] || 0;
    }

    getDescription(projectId) {
        return this.entries[projectId]?.description || '';
    }
}

