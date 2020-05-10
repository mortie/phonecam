#include "HttpServer.h"

#include <httplib.h>
#include <iostream>
#include <stdexcept>
#include <time.h>

#include "web.h"

namespace http = httplib;

template<typename T, void (*del)(T *)>
struct CPtrDeleter {
	void operator()(T *ptr) const {
		del(ptr);
	}
};

template<typename T, void (*del)(T *)>
using CPtr = std::unique_ptr<T, CPtrDeleter<T, del>>;

HttpServer::HttpServer() {}
HttpServer::~HttpServer() {}

void HttpServer::beginMessage(const char *type) {
	if (message_queue_.size() == 0) {
		message_queue_.append("[{\"type\":\"");
	} else {
		message_queue_.append(",{\"type\":\"");
	}

	message_queue_.append(type);
	message_queue_.append("\"");
}

void HttpServer::completeMessage() {
	message_queue_.push_back('}');
}

void HttpServer::messageError(const char *str) {
	messageKey("error");
	messageValString(str);
}

void HttpServer::messageKey(const char *str) {
	message_queue_.push_back('"');
	message_queue_.append(str);
	message_queue_.append("\":");
}

void HttpServer::messageValString(const char *str) {
	message_queue_.push_back('"');

	size_t start = 0;
	size_t i;
	for (i = 0; str[i]; ++i) {
		if (str[i] == '"') {
			message_queue_.append(str + start, i - start);
			message_queue_.append("\\\"");
			start = i + 1;
		} else if (str[i] == '\\') {
			message_queue_.append(str + start, i - start);
			message_queue_.append("\\\\");
			start = i + 1;
		}
	}

	message_queue_.append(str + start, i - start);
	message_queue_.push_back('"');
}

void HttpServer::sendStartStream() {
	std::lock_guard<std::mutex> lock(message_queue_mx_);
	beginMessage("start-stream");
	completeMessage();
}

void HttpServer::run(int port, HttpServerObserver *observer) {
	// Private key
	CPtr<EVP_PKEY, EVP_PKEY_free> pkey(EVP_PKEY_new());

	// Generate SSL RSA key
	CPtr<BIGNUM, BN_free> exponent(BN_new());
	BN_set_word(exponent.get(), RSA_F4);
	CPtr<RSA, RSA_free> rsa(RSA_new());
	RSA_generate_key_ex(rsa.get(), 2048, exponent.get(), NULL);
	EVP_PKEY_set1_RSA(pkey.get(), rsa.get());

	// Generate certificate
	CPtr<X509, X509_free> x509(X509_new());
	X509_set_version(x509.get(), 3);
	ASN1_INTEGER_set(X509_get_serialNumber(x509.get()), time(0));
	X509_gmtime_adj(X509_get_notBefore(x509.get()), 0);
	X509_gmtime_adj(X509_get_notAfter(x509.get()), (long)60*60*24*365);
	X509_set_pubkey(x509.get(), pkey.get());

	// Generate certificate information
	X509_NAME *certname = X509_get_subject_name(x509.get());
	X509_NAME_add_entry_by_txt(certname, "C", MBSTRING_ASC,
		(unsigned char *)"NO", -1, -1, 0);
	X509_NAME_add_entry_by_txt(certname, "O", MBSTRING_ASC,
		(unsigned char *)"mort", -1, -1, 0);
	X509_NAME_add_entry_by_txt(certname, "CN", MBSTRING_ASC,
		(unsigned char *)"localhost", -1, -1, 0);
	X509_set_issuer_name(x509.get(), certname);

	// Sign the cert
	if (!X509_sign(x509.get(), pkey.get(), EVP_sha256())) {
		throw std::runtime_error("Failed to sign X509 cert");
	}

	// Create SSL server with our cert
	server_ = std::make_unique<http::SSLServer>(x509.get(), pkey.get(), nullptr);
	auto &srv = *server_;

	srv.Get("/", [](const auto &req, auto &res) {
		res.set_content(web_index_html_data, web_index_html_len, "text/html");
	});

	srv.Get("/index.html", [](const auto &req, auto &res) {
		res.set_content(web_index_html_data, web_index_html_len, "text/html");
	});

	srv.Get("/script.js", [](const auto &req, auto &res) {
		res.set_content(web_script_js_data, web_script_js_len, "application/javascript");
	});

	srv.Post("/api/poll", [=](const auto &req, auto &res) {
		std::lock_guard<std::mutex> lock(message_queue_mx_);

		if (message_queue_.size() == 0) {
			res.set_content("[]", "application/json");
		} else {
			message_queue_.push_back(']');
			res.set_content(std::move(message_queue_), "application/json");
			message_queue_.clear();
		}
	});

	srv.Post("/api/connect", [=](const auto &req, auto &res) {
		{ // The new sender shouldn't see old messages
			std::lock_guard<std::mutex> lock(message_queue_mx_);
			message_queue_.clear();
		}

		observer->onSenderConnected();
		res.set_content("{}", "application/json");
	});

	srv.Post("/api/disconnect", [=](const auto &req, auto &res) {
		observer->onSenderDisconnected();
		res.set_content("{}", "application/json");
	});

	std::cerr << "Listening on 0.0.0.0:" << port << '\n';
	srv.listen("0.0.0.0", port);
}

void HttpServer::stop() {
	server_->stop();
	server_.reset();
}
