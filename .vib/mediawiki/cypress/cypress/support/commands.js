const COMMAND_DELAY = 500;
const BASE_URL = 'http://bitnami-mediawiki.my';

for (const command of ['click']) {
  Cypress.Commands.overwrite(command, (originalFn, ...args) => {
    const origVal = originalFn(...args);

    return new Promise((resolve) => {
      setTimeout(() => {
        resolve(origVal);
      }, COMMAND_DELAY);
    });
  });
}

Cypress.Commands.overwrite('visit', (originalFn, url, options) => {
  return originalFn(`${BASE_URL}${url}`, options);
});

Cypress.Commands.add(
  'login',
  (username = Cypress.env('username'), password = Cypress.env('password')) => {
    cy.clearCookies();
    cy.visit('/index.php?title=Special:UserLogin');
    cy.get('#wpName1').type(username);
    cy.get('#wpPassword1').type(password);
    cy.contains('button', 'Log in').click();
  }
);
