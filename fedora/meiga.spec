Name:		meiga
Version:	0.4.0
Release:	1%{?dist}
Summary:	Easy to use tool to share selected local directories via web

Group:		Applications/Internet
License:	GPLv2+
URL:		http://meiga.igalia.com/
Source0:	http://meiga.igalia.com/packages/src/%{name}-%{version}.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires:	gnome-common
BuildRequires:	intltool
BuildRequires:	libtool
# Not needed because source releases are now precompiled
# BuildRequires:	vala
BuildRequires:	libsoup-devel
BuildRequires:	gupnp-devel
BuildRequires:	dbus-glib-devel
BuildRequires:	desktop-file-utils
Requires:	dbus
Requires:	gtk2
Requires:	gupnp
Requires:	hicolor-icon-theme
Requires:	openssl

%description
Meiga is a lightweight, easy to use, network friendly and also
application friendly content server for desktop.
Client side does not need to install any software, as the
shared files can be accessed using web browser. The ultimate
goal is to serve as a common publishing pont for desktop
applications, such as file manager, picture viewers or
music players

%package -n %{name}-kde
Summary: Meiga KDE integration package
Group: Applications/Internet
Requires: kde-filesystem
Requires: %{name}
%description -n %{name}-kde
Enables the Meiga KDE integration


%prep
%setup -q

%build
./autogen.sh
%configure
make %{?_smp_mflags}


%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT

desktop-file-install --vendor=""					\
		--delete-original					\
		--dir=$RPM_BUILD_ROOT%{_datadir}/applications		\
		$RPM_BUILD_ROOT%{_datadir}/applications/%{name}.desktop
%find_lang %{name}

%clean
rm -rf $RPM_BUILD_ROOT

%post
update-desktop-database -q
if [ -x /usr/bin/gtk-update-icon-cache ]; then
  /usr/bin/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor
  /usr/bin/gtk-update-icon-cache --quiet %{_datadir}/pixmaps
fi

%postun
update-desktop-database -q
if [ -x /usr/bin/gtk-update-icon-cache ]; then
  /usr/bin/gtk-update-icon-cache --quiet %{_datadir}/icons/hicolor
  /usr/bin/gtk-update-icon-cache --quiet %{_datadir}/pixmaps
fi


%files -f %{name}.lang
%defattr(-,root,root,-)
%{_bindir}/fwlocalip
%{_bindir}/fwfon
%{_bindir}/fwupnp
%{_bindir}/fwssh
%{_bindir}/fwssh-task
%{_bindir}/meiga
%{_bindir}/meigaserver
%{_bindir}/meiga-askpass
%{_bindir}/make-meiga-ssl-cert
%{_datadir}/nautilus-scripts/share-on-meiga
%{_datadir}/dbus-1/services/com.igalia.Meiga.service
%{_datadir}/applications/%{name}.desktop
%dir %{_datadir}/%{name}
%{_datadir}/%{name}/*
%{_datadir}/pixmaps/%{name}.png
%{_datadir}/icons/hicolor/48x48/apps/%{name}.png

%doc AUTHORS COPYING ChangeLog MAINTAINERS README

%files -n %{name}-kde
%{_datadir}/apps/konqueror/servicemenus/%{name}-kde3.desktop
%{_datadir}/kde4/services/ServiceMenus/%{name}-kde4.desktop


%changelog
* Sat Jun 05 2010 Rajeesh K Nambiar <rajeeshknambiar@gmail.com> - 0.3.3-1
- Fix for FTBFS RHBZ #599951 : Vala compiler segfault
- Added gnome-common as BR

* Mon Feb 08 2010 Rajeesh K Nambiar <rajeeshknambiar@gmail.com> - 0.3.2-1
- Doesn't use GtkBuilder anymore
- Files are now iterated instead of mmapped
- Fix for RHBZ #559390

* Sun Nov 15 2009 Rajeesh K Nambiar <rajeeshknambiar@gmail.com> - 0.3.1-2
- Split the KDE specific files into meiga-kde package
- Added --force to intltoolize in %build

* Wed Nov 11 2009 Rajeesh K Nambiar <rajeeshknambiar@gmail.com> - 0.3.1-1
- Update to version 0.3.1

* Thu Oct 08 2009 Rajeesh K Nambiar <rajeeshknambiar@gmail.com> - 0.3.0-1
- Update to new version 0.3.0

* Tue Jul 28 2009 Rajeesh K Nambiar <rajeeshknambiar@gmail.com> - 0.2.1-2
- Update spec as per review comments

* Thu Jul 02 2009 Rajeesh K Nambiar <rajeeshknambiar@gmail.com> - 0.2.1-1
- Update to 0.2.1. Fixes issue with internal IP not finding in Fedora

* Fri Jun 26 2009 Rajeesh K Nambiar <rajeeshknambiar@gmail.com> - 0.2.0-1
- Initial package
