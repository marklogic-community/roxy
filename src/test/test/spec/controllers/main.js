'use strict';

describe('Hello World', function () {

  // load the controller's module
  // beforeEach(module('YoemanApp'));

  var scope;

  // Initialize the controller and a mock scope
  beforeEach(inject(function ($controller, $rootScope) {
    scope = $rootScope.$new();
  }));

  it('one plus one is two', function () {
    expect(1 + 1).toBe(2);
  });
});
