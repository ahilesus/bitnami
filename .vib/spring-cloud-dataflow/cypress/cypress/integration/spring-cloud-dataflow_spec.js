/// <reference types="cypress" />
import { random } from './utils';

it('allows getting Spring Cloud Dataflow info', () => {
  cy.visit('/dashboard');
  cy.get('.signpost-trigger').click();
  cy.contains('.signpost-content-body', 'Version');
  cy.contains('button', 'More info').click();
  cy.contains('.modal-content', 'Core')
    .and('contain', 'Dashboard')
    .and('contain', 'Shell');
});

it('can import a stream application and create a stream', () => {
  cy.visit('/dashboard');
  cy.contains('button', 'Add application(s)').click();
  cy.contains(
    '.clr-control-label',
    'Stream application starters for Kafka/Maven'
  ).click();
  cy.contains('.btn-primary', 'Import').click();
  cy.get('.toast-container').should('contain', 'Application(s) Imported');
  cy.get('.content-area')
    .should('contain', 'processor')
    .and('contain', 'sink')
    .and('contain', 'source');
  cy.visit('/dashboard');
  cy.get('[routerlink="streams/list"').click();
  cy.contains('.btn-primary', 'Create stream(s)').click();
  cy.get('.CodeMirror-line').type('mongodb | cassandra');
  cy.get('#v-2').should('contain', 'mongodb').and('contain', 'cassandra');
  cy.contains('button', 'Create stream(s)').click();
  cy.get('.modal-content').should('contain', 'Create Stream');
  cy.fixture('streams').then((stream) => {
    cy.get('input[placeholder="Stream Name"]').type(
      `${stream.newStream.name}-${random}`
    );
    cy.contains('.btn-primary', 'Create the stream').click();
    cy.contains('.modal-content', 'Creating Stream');
    cy.contains(
      '.datagrid-inner-wrapper',
      `${stream.newStream.name}-${random}`
    );
  });
});

it('allows importing a task application and creating a task', () => {
  const TASK_TYPE = 'timestamp';
  cy.visit('/dashboard');
  cy.contains('button', 'Add application(s)').click();
  cy.contains(
    '.clr-control-label',
    'Task application starters for Maven'
  ).click();
  cy.contains('.btn-primary', 'Import').click();
  cy.get('.toast-container').should('contain', 'Application(s) Imported');
  cy.get('[routerlink="tasks-jobs/tasks"]').click();
  cy.contains('button', 'Create task').click();
  cy.get('.content-area')
    .should('contain', 'timestamp')
    .and('contain', 'timestamp-batch');
  cy.visit('/dashboard');
  cy.get('[routerlink="tasks-jobs/tasks"]').click();
  cy.contains('.btn-primary', 'Create task').click();
  cy.get('.CodeMirror-line').type(TASK_TYPE);
  cy.contains('#v-2', TASK_TYPE);
  cy.contains('button', 'Create task').click();
  cy.contains('.modal-content', 'Create task');
  cy.fixture('tasks').then((task) => {
    cy.get('input[placeholder="Task Name"]').type(
      `${task.newTask.name}-${random}`
    );
    cy.contains('.btn-primary', 'Create the task').click();
    cy.contains('.datagrid-inner-wrapper', `${task.newTask.name}-${random}`);
  });
});

it('allows importing a task from a file and destroying it ', () => {
  cy.visit('/dashboard');
  cy.get('[routerlink="manage/tools"]').click();
  cy.contains('a', 'Import tasks from a JSON file').click();
  cy.get('input[type="file"]').selectFile(
    'cypress/fixtures/task-to-import.json',
    { force: true }
  );
  cy.contains('button', 'Import').click();
  cy.contains('.modal-body', '1 task(s) created');
  cy.get('.close').click();
  cy.get('[routerlink="tasks-jobs/tasks"]').click();
  cy.contains('button', 'Group Actions').click();
  cy.get('[aria-label="Select All"]').click({ force: true });
  cy.contains('button', 'Destroy task').click(); //since I can't play with the file name when
  cy.contains('.modal-content', 'Confirm Destroy Task');
  cy.contains('button', 'Destroy the task').click();
  cy.get('.toast-container').should('contain', 'destroyed');
});
