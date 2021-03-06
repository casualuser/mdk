quark 1.0;

import quark.test;
import quark.mock;
import quark.error;
import quark.reflect;

use ../mdk_runtime.q;
import mdk_runtime.actors;
import mdk_runtime.promise;

void main(List<String> args) {
    test.run(args);
}

class PromiseValueTest {
    void testNoValue() {
        PromiseValue value = new PromiseValue(null, null, false);
        checkEqual(false, value.hasValue());
    }

    void testSuccessValue() {
        PromiseValue value = new PromiseValue("hello", null, true);
        checkEqual(true, value.hasValue());
        checkEqual(false, value.isError());
        checkEqual("hello", value.getValue());
    }

    void testErrorValue() {
        Error e = new Error("e");
        PromiseValue value = new PromiseValue(null, e, true);
        checkEqual(true, value.hasValue());
        checkEqual(true, value.isError());
        checkEqual(e, value.getValue());
    }
}

class StoreValue extends UnaryCallable {
    Object result = null;
    bool called = false;

    Object call(Object arg) {
        self.result = arg;
        self.called = true;
        return null;
    }
}

class ReturnValue extends UnaryCallable {
    Object returnme;

    ReturnValue(Object returnme) {
        self.returnme = returnme;
    }

    Object call(Object arg) {
        return self.returnme;
    }
}

class StoreContext extends UnaryCallable {
    Context recorded = null;

    Object call(Object arg) {
        self.recorded = Context.current();
        return true;
    }
}

macro Object makeUndefined() $js{undefined} $java{null};

class PromiseTest extends MockRuntimeTest {
    MessageDispatcher dispatcher;

    void setup() {
        super.setup();
        dispatcher = new MessageDispatcher(new _ManualLaterCaller());
    }

    void spinCollector() {
        self.dispatcher.pump();
        self.pump();
        self.dispatcher.pump();
        self.pump();
        self.dispatcher.pump();
        self.pump();
        self.dispatcher.pump();
        self.pump();
        self.dispatcher.pump();
    }

    static String theValue = "success!";
    static error.Error theError = new Error("err");

    // No value on initial creation
    void testNoValue() {
        Promise p = new PromiseResolver(self.dispatcher).promise;
        StoreValue success = new StoreValue();
        StoreValue failure = new StoreValue();
        StoreValue both = new StoreValue();
        p.andThen(success);
        p.andCatch(Class.ERROR, failure);
        p.andFinally(both);
        spinCollector();
        checkEqual(false, success.called);
        checkEqual(false, failure.called);
        checkEqual(false, both.called);
        checkEqual(false, p.value().hasValue());
    }

    // Success value becomes available to success callback and either-way
    // callback when a resolve() is done before a callback is added.
    void testSuccessValueCallbackBefore() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        f.resolve(?theValue);
        spinCollector();
        StoreValue success = new StoreValue();
        StoreValue failure = new StoreValue();
        StoreValue both = new StoreValue();
        p.andThen(success);
        p.andCatch(Class.ERROR, failure);
        p.andFinally(both);
        spinCollector();
        checkEqual(true, success.called);
        checkEqual(theValue, success.result);
        checkEqual(false, failure.called);
        checkEqual(true, both.called);
        checkEqual(theValue, both.result);
        checkEqual(true, p.value().hasValue());
        checkEqual(theValue, p.value().getValue());
    }

    // Success value becomes available to success callback and either-way
    // callback when a resolve() is done after a callback is added.
    void testSuccessValueCallbackAfter() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue success = new StoreValue();
        StoreValue failure = new StoreValue();
        StoreValue both = new StoreValue();
        p.andThen(success);
        p.andCatch(Class.ERROR, failure);
        p.andFinally(both);
        spinCollector();
        f.resolve(?theValue);
        spinCollector();
        checkEqual(true, success.called);
        checkEqual(theValue, success.result);
        checkEqual(false, failure.called);
        checkEqual(true, both.called);
        checkEqual(theValue, both.result);
        checkEqual(true, p.value().hasValue());
        checkEqual(theValue, p.value().getValue());
    }

    // Error value becomes available to error callback and either-way callback
    // when a resolve() is done before a callback is added.
    void testErrorValueCallbackBefore() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        f.reject(?theError);
        spinCollector();
        StoreValue success = new StoreValue();
        StoreValue failure = new StoreValue();
        StoreValue both = new StoreValue();
        p.andThen(success);
        p.andCatch(Class.ERROR, failure);
        p.andFinally(both);
        spinCollector();
        checkEqual(false, success.called);
        checkEqual(true, failure.called);
        checkEqual(theError, failure.result);
        checkEqual(true, both.called);
        checkEqual(theError, both.result);
        checkEqual(true, p.value().hasValue());
        checkEqual(theError, p.value().getValue());
    }

    // Error value becomes available to error callback and either-way callback
    // when a resolve() is done after a callback is added.
    void testErrorValueCallbackAfter() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue success = new StoreValue();
        StoreValue failure = new StoreValue();
        StoreValue both = new StoreValue();
        p.andThen(success);
        p.andCatch(Class.ERROR, failure);
        p.andFinally(both);
        spinCollector();
        f.reject(theError);
        spinCollector();
        checkEqual(false, success.called);
        checkEqual(true, failure.called);
        checkEqual(theError, failure.result);
        checkEqual(true, both.called);
        checkEqual(theError, both.result);
        checkEqual(true, p.value().hasValue());
        checkEqual(theError, p.value().getValue());
    }

    // andCatch only catches errors that are instances of given class.
    void testErrorFiltering() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        HTTPError err = new HTTPError("ONO");
        f.reject(err);
        spinCollector();
        StoreValue failure = new StoreValue();
        StoreValue httpFailure = new StoreValue();
        StoreValue servletFailure = new StoreValue();
        p.andCatch(Class.ERROR, failure);
        p.andCatch(Class.get("quark.HTTPError"), httpFailure);
        p.andCatch(Class.get("quark.ServletError"), servletFailure);
        spinCollector();
        checkEqual(true, failure.called);
        checkEqual(err, failure.result);
        checkEqual(true, httpFailure.called);
        checkEqual(err, httpFailure.result);
        checkEqual(false, servletFailure.called);
    }

    // Success callback passes through error values:
    void testErrorPassthrough() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        f.reject(theError);
        spinCollector();
        StoreValue success = new StoreValue();
        StoreValue failure = new StoreValue();
        p.andThen(success).andCatch(Class.ERROR, failure);
        spinCollector();
        checkEqual(false, success.called);
        checkEqual(true, failure.called);
        checkEqual(theError, failure.result);
    }

    // Error callback passes through success values:
    void testSuccessPassthrough() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue success = new StoreValue();
        StoreValue failure = new StoreValue();
        p.andCatch(Class.ERROR, failure).andThen(success);
        f.resolve(theValue);
        spinCollector();
        checkEqual(false, failure.called);
        checkEqual(true, success.called);
        checkEqual(theValue, success.result);
    }

    // Success callback returning error switches to error path
    void testSuccessReturningError() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue failure = new StoreValue();
        p.andThen(new ReturnValue(theError)).andCatch(Class.ERROR, failure);
        f.resolve(theValue);
        spinCollector();
        checkEqual(true, failure.called);
        checkEqual(theError, failure.result);
    }

    // Calling resolve() with an error turns it into a reject():
    // (Made this mistake myself... seems most reasonable thing to do).
    void testResolveWithErrorDoesReject() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue failure = new StoreValue();
        p.andCatch(Class.ERROR, failure);
        f.resolve(theError); // resolve() not reject()!
        spinCollector();
        checkEqual(true, failure.called);
        checkEqual(theError, failure.result);
    }

    // Error callback returning not-error switches to success path
    void testErrorReturningSuccess() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue success = new StoreValue();
        p.andCatch(Class.ERROR, new ReturnValue(theValue)).andThen(success);
        f.reject(theError);
        spinCollector();
        checkEqual(true, success.called);
        checkEqual(theValue, success.result);
    }

    // Callback returning value-less promise is chained on success path when the
    // promise is resolved.
    void testCallbackReturningUnresolvedPromiseSuccess() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        PromiseResolver o = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue success = new StoreValue();
        p.andThen(new ReturnValue(o.promise)).andThen(success);
        f.resolve(123);
        spinCollector();
        checkEqual(false, success.called);
        o.resolve(456);
        spinCollector();
        checkEqual(true, success.called);
        checkEqual(456, success.result);
    }

    // Callback returning promise with value is chained on success path when the
    // promise is resolved.
    void testCallbackReturningResolvedPromiseSuccess() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        PromiseResolver o = new PromiseResolver(self.dispatcher);
        o.resolve(456);
        Promise p = f.promise;
        StoreValue success = new StoreValue();
        p.andThen(new ReturnValue(o.promise)).andThen(success);
        f.resolve(123);
        spinCollector();
        checkEqual(true, success.called);
        checkEqual(456, success.result);
    }

    // Callback returning value-less promise is chained on error path when the
    // promise is rejected.
    void testCallbackReturningUnresolvedPromiseError() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        PromiseResolver o = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue failure = new StoreValue();
        p.andThen(new ReturnValue(o.promise)).andCatch(Class.ERROR, failure);
        f.resolve(123);
        spinCollector();
        checkEqual(false, failure.called);
        o.reject(theError);
        spinCollector();
        checkEqual(true, failure.called);
        checkEqual(theError, failure.result);
    }

    // Callback returning promise with value is chained on error path when the
    // promise is rejected.
    void testCallbackReturningResolvedPromiseError() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        PromiseResolver o = new PromiseResolver(self.dispatcher);
        o.reject(theError);
        Promise p = f.promise;
        StoreValue failure = new StoreValue();
        p.andThen(new ReturnValue(o.promise)).andCatch(Class.ERROR, failure);
        f.resolve(123);
        spinCollector();
        checkEqual(true, failure.called);
        checkEqual(theError, failure.result);
    }

    // Resolving a Promise calls the success callback when both are given
    void testResolveEitherSuccess() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue success = new StoreValue();
        StoreValue failure = new StoreValue();
        p.andEither(success, failure);
        f.resolve(theValue);
        spinCollector();
        checkEqual(false, failure.called);
        checkEqual(true, success.called);
        checkEqual(theValue, success.result);
    }

    // Rejecting a Promise calls the error callback when both are given
    void testResolveEitherError() {
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue success = new StoreValue();
        StoreValue failure = new StoreValue();
        p.andEither(success, failure);
        f.reject(theError);
        spinCollector();
        checkEqual(true, failure.called);
        checkEqual(false, success.called);
        checkEqual(theError, failure.result);
    }

    Object _jsUndefined(Object ignore) {
        return makeUndefined();
    }

    // Javascript undefined is converted into a null when returned from a
    // UnaryCallable:
    void testJSUndefinedResult() {
        if (!isJavascript()) {
            return;
        }
        PromiseResolver f = new PromiseResolver(self.dispatcher);
        Promise p = f.promise;
        StoreValue success = new StoreValue();
        p.andThen(bind(self, "_jsUndefined", [])).andThen(success);
        f.resolve(true);
        spinCollector();
        checkEqual(true, success.called);
        checkEqual(null, success.result);
    }

    // Nice to have tests but unlikely use cases:
    // Re-entrancy: callback registered inside error callback is called
    // Re-entrancy: callback registered inside either-way callback is called
    // Re-entrancy: callback registered inside success callback is called
}
