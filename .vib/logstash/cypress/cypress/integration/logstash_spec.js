/// <reference types="cypress" />

it('can check cluster health', () => {
  cy.request({
    method: 'GET',
    url: '/',
    form: true,
  }).then((response) => {
    expect(response.status).to.eq(200);
    expect(response.body.status).to.contain('green');
  });
});
