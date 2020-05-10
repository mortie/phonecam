#pragma once

#include <memory>
#include <mutex>

namespace httplib { class SSLServer; }

class HttpServerObserver {
public:
	virtual void onSenderConnected() = 0;
	virtual void onSenderDisconnected() = 0;
};

class HttpServer {
public:
	HttpServer();
	~HttpServer();

	void sendStartStream();

	void run(int port, HttpServerObserver *observer);
	void stop();

private:
	void beginMessage(const char *type);
	void messageError(const char *str);
	void messageKey(const char *str);
	void messageValString(const char *str);
	void completeMessage();

	std::unique_ptr<httplib::SSLServer> server_;
	std::string message_queue_;
	std::mutex message_queue_mx_;
};
