#include "HttpServer.h"

#include <iostream>

class Observer: public HttpServerObserver {
public:
	Observer(HttpServer *server): server_(server) {}

	void onSenderConnected() override {
		std::cerr << "onSenderConnected\n";
		server_->sendStartStream();
	}

	void onSenderDisconnected() override {
		std::cerr << "onSenderDisconnected\n";
	}

private:
	HttpServer *server_;
};

int main() {
	HttpServer server;
	Observer obs(&server);

	server.run(8080, &obs);
}
